class RmptUserTest < ActiveRecord::Base
  belongs_to :test, class_name: 'RmptTest', foreign_key: :test_id, optional: true
  belongs_to :user, class_name: 'User', foreign_key: :user_id, optional: true

  has_many :questions, class_name: 'RmptUserQuestion', foreign_key: :test_id, dependent: :destroy, inverse_of: :test

  include Rmpt::Testable

  scope :uncompleted, -> { where(completed: false) }

  scope :actual, lambda { |*args|
    user = args[0]
    now = Time.now

    scope = uncompleted
            .where("#{RmptUserTest.table_name}.expired = ? OR #{RmptUserTest.table_name}.expired IS NULL", false)
            .where("(
                        #{RmptUserTest.table_name}.timelimit_q IS NULL
                        OR
                        #{RmptUserTest.table_name}.start_at IS NULL
                        OR
                        COALESCE(#{RmptUserTest.table_name}.q_count_total, 0) - COALESCE(#{RmptUserTest.table_name}.q_count_touch, 0) > 0
                        OR
                        #{RmptTest.connection.rmp_seconds_diff("COALESCE(#{RmptUserTest.table_name}.last_q_touch_at, #{RmptUserTest.table_name}.start_at)", RmptTest.connection.quote(RmptTest.connection.quoted_date(now)))} - #{RmptUserTest::SECONDS_LAG} <= #{RmptUserTest.table_name}.timelimit_q
                    )
                AND (
                      #{RmptUserTest.table_name}.timelimit_total IS NULL
                      OR
                      #{RmptUserTest.table_name}.start_at IS NULL
                      OR
                      (#{RmptTest.connection.rmp_seconds_diff("#{RmptUserTest.table_name}.start_at", "COALESCE(#{RmptUserTest.table_name}.end_at, #{RmptTest.connection.quote(RmptTest.connection.quoted_date(now))})")} - #{RmptUserTest::SECONDS_LAG} <= #{RmptUserTest.table_name}.timelimit_total)
                    )
                   ")

    if user.present?
      scope.where(user_id: user.id)
    else
      scope
    end
  }

  scope :expired, lambda { |*args|
    user = args[0]
    now = Time.now

    scope = uncompleted
              .where("#{RmptUserTest.table_name}.expired = ? OR #{RmptUserTest.table_name}.expired IS NULL", true)
              .where("(
                          #{RmptUserTest.table_name}.timelimit_q IS NOT NULL
                          AND
                          #{RmptUserTest.table_name}.start_at IS NOT NULL
                          AND
                          COALESCE(q_count_total, 0) - COALESCE(q_count_touch, 0) = 0
                          AND
                          #{RmptTest.connection.rmp_seconds_diff("COALESCE(#{RmptUserTest.table_name}.last_q_touch_at, #{RmptUserTest.table_name}.start_at)", RmptTest.connection.quote(RmptTest.connection.quoted_date(now)))} - #{RmptUserTest::SECONDS_LAG} > #{RmptUserTest.table_name}.timelimit_q
                      )
                   OR (
                          #{RmptUserTest.table_name}.timelimit_total IS NOT NULL
                          AND
                          #{RmptUserTest.table_name}.start_at IS NOT NULL
                          AND
                          (#{RmptTest.connection.rmp_seconds_diff("#{RmptUserTest.table_name}.start_at", "COALESCE(#{RmptUserTest.table_name}.end_at, #{RmptTest.connection.quote(RmptTest.connection.quoted_date(now))})")} - #{RmptUserTest::SECONDS_LAG} > #{RmptUserTest.table_name}.timelimit_total)
                      )
                     ")

    if user.present?
      scope.where(user_id: user.id)
    else
      scope
    end
  }

  validate :validate_access

  before_create :validate_create_test

  STATUS_SUCCESS = 0
  STATUS_FAILED = 1
  STATUS_TIMELIMIT_EXPIRED = 2
  STATUS_STARTED = 3
  STATUS_BLANK = 4

  REPORT_STATUSES = [STATUS_BLANK, STATUS_STARTED, STATUS_SUCCESS, STATUS_FAILED]

  SECONDS_LAG = 5

  def attempts
    self.test.attempts
  end

  def enroll_date
    return @enroll_date if @enroll_date
    @enroll_date = RmptTest.enrolled(self.user, self.test).to_a.first.attributes['enrolled_date'] || self.user.today
  end

  def due
    if self.test.due_days
      if self.enroll_date
        self.enroll_date + self.test.due_days.days
      else
        nil
      end
    elsif self.test.due_date
      self.test.due_date
    else
      nil
    end
  end

  def timelimited?
    self.timelimit_total.present? || self.timelimit_q.present?
  end

  def time_used
    ((self.end_at || Time.now) - (self.start_at || Time.now)).to_i
  end

  def timelimit_left
    return if self.timelimit_total.blank?
    self.timelimit_total.to_i - self.time_used
  end

  def expired?
    return self.expired unless self.expired.nil?

    if self.timelimit_q.present?
      if self.q_count_total.to_i - self.q_count_touch.to_i > 0
        return false
      end

      max_at = self.last_q_touch_at || self.start_at
      ((self.end_at || Time.now) - max_at).to_i - RmptUserTest::SECONDS_LAG > self.timelimit_q.to_i
    elsif self.timelimit_total.present?
      self.timelimit_left + RmptUserTest::SECONDS_LAG < 0
    else
      false
    end
  end

  def status
    status = super
    if status == STATUS_STARTED
      if self.expired?
        return STATUS_TIMELIMIT_EXPIRED
      else
        return STATUS_STARTED
      end
    end
    status
  end

  def passed?
    return self.passed unless self.passed.nil?
    if self.min_pass_percent.present?
      self.result_ratio.to_f >= self.min_pass_percent
    elsif self.min_pass.present? && self.min_pass <= self.q_count_total.to_i
      self.q_count_correct.to_i >= self.min_pass
    else
      self.q_count_correct.to_i >= self.q_count_total.to_i
    end
  end

  def status_blank?
    self.status == STATUS_BLANK
  end

  def status_started?
    self.status == STATUS_STARTED
  end

  def status_success?
    self.status == STATUS_SUCCESS
  end

  def has_access?(user = User.current)
    self.user_id == user.id
  end

  def has_access_result?(user = User.current)
    self.show_t_result? && self.completed? && self.has_access?(user)
  end

  def q_count_completed
    self.questions.inject(0) { |sum, q| sum += q.completed? || q.expired? ? 1 : 0 }.to_i
  end

  def question_by_num(num)
    num = num.to_i
    return nil if num <= 0
    self.questions.where(num: num).first
  end

  def closest_question(num=nil)
    num = num.to_i

    if num > 0 && self.can_skip? && self.can_resubmit?
      self.questions.actual.order(Arel.sql("case when #{RmptUserQuestion.table_name}.num = #{num} then 0 else 1 end ASC, #{RmptUserQuestion.table_name}.num ASC")).first
    elsif num > 0 && self.can_skip?
      self.questions.actual.where("#{RmptUserQuestion.table_name}.completed = ?", false).order(Arel.sql("case when #{RmptUserQuestion.table_name}.num = #{num} then 0 else 1 end ASC, #{RmptUserQuestion.table_name}.num ASC")).first
    elsif num > 0 && self.can_resubmit?
      self.questions.actual.where("#{RmptUserQuestion.table_name}.completed = ? OR (#{RmptUserQuestion.table_name}.completed = ? AND #{RmptUserQuestion.table_name}.num = ?)", false, true, num).order(Arel.sql("case when #{RmptUserQuestion.table_name}.completed = #{RmptUserQuestion.connection.quoted_true} and #{RmptUserQuestion.table_name}.num = #{num} then 0 else 1 end ASC, #{RmptUserQuestion.table_name}.num ASC")).first
    else
      self.questions.actual.where("#{RmptUserQuestion.table_name}.completed = ?", false).order("#{RmptUserQuestion.table_name}.num ASC").first
    end
  end

  def next_question(num=nil)
    num = num.to_i

    if num > 0 && self.can_skip?
      self.questions.actual.where("#{RmptUserQuestion.table_name}.completed = ?", false).order(Arel.sql("case when #{RmptUserQuestion.table_name}.num = #{num} then 0 else 1 end ASC, #{RmptUserQuestion.table_name}.num ASC")).first
    else
      self.questions.actual.where("#{RmptUserQuestion.table_name}.completed = ?", false).order("#{RmptUserQuestion.table_name}.num ASC").first
    end
  end


  def ensure_start_step!
    unless self.has_access?
      self.errors.add(:base, l(:error_rmpt_user_test_access_denied))
      return false
    end

    if self.status_blank?
      self.start_at = Time.now
      self.q_count_correct = 0
      self.result_ratio = nil
      self.completed = false
      self.q_count_touch = 0

      if self.q_count_total == 0
        self.end_at = Time.now
        self.completed = true
        self.passed = true
        self.result_ratio = 100
      end
    end
    self.status = get_status
    self.save
  end

  def touch_step!(q_num)
    # пытаемся получить вопрос по порядковому номеру, не факт, что вернет именно вопрос с переданным номером,
    # т.к. вопрос может быть уже отвечеи и переотвечать нельзя, пропускать вопросы нельзя, вопрос может быть уже просрочен
    unless self.has_access?
      self.errors.add(:base, l(:error_rmpt_user_test_access_denied))
      return false
    end

    if self.status_blank?
      return false unless self.ensure_start_step!
    end
    unless self.status_started?
      return false unless self.complete_step!
      return nil
    end

    question = self.question_by_num(q_num)
    if question.blank? || !question.can_answer?
      question = self.closest_question(q_num)
    end

    RmptUserTest.transaction do
      if question.blank?
        return false unless self.complete_step!
        return nil
      end

      was_touch = question.touched?

      unless question.touch_step!
        question.errors.full_messages.each do |err|
          self.errors.add(:base, err)
        end
        return false
      end

      unless was_touch
        self.last_q_touch_at = question.start_at
        self.q_count_touch = self.q_count_touch.to_i + 1
      end

      unless self.save
        raise ActiveRecord::Rollback
      end
      return question
    end

    false
  end

  def store_step!(q_num, params)
    if params.respond_to?(:to_unsafe_hash)
      params = params.to_unsafe_hash
    end
    # пытаемся ответить на вопрос, в результате получим отвеченый вопрос и следующий вопрос, если он есть
    # здесь же и завершиться тест, если нет больше вопросов (следующий вопрос - пустой)
    unless self.has_access?
      self.errors.add(:base, l(:error_rmpt_user_test_access_denied))
      return false
    end

    if self.status_blank?
      return false unless self.ensure_start_step!
    end

    unless self.status_started?
      return false unless self.complete_step!
      return nil
    end

    question = self.question_by_num(q_num)
    if question.blank?
      self.errors.add(:base, l(:error_rmpt_user_test_step_unknown_question, num: q_num.to_i))
      return false
    end

    was_completed = question.completed?
    was_touch = question.touched?
    was_correct = question.correct?

    RmptUserTest.transaction do
      unless question.store_step!(params)
        question.errors.full_messages.each do |err|
          self.errors.add(:base, err)
        end
        return false
      end

      if !was_correct && question.correct?
        self.q_count_correct = self.q_count_correct.to_i + 1
      end

      if was_correct && !question.correct?
        self.q_count_correct = self.q_count_correct.to_i - 1
      end

      unless was_touch
        self.last_q_touch_at = question.end_at
        self.q_count_touch = self.q_count_touch.to_i + 1
      end

      self.questions.expired.where("#{RmptUserQuestion.table_name}.expired IS NULL").update_all(["#{RmptUserQuestion.table_name}.completed = ?, #{RmptUserQuestion.table_name}.expired = ?", true, true])

      if was_completed
        next_q = self.next_question
      else
        next_q = self.next_question(question.num + 1)
      end

      if next_q.blank?
        self.complete_step
      end

      unless self.save
        raise ActiveRecord::Rollback
      end
      return { q: question, next: next_q }
    end

    false
  end

  def complete_step
    self.end_at = Time.now
    self.completed = true
    self.expired = self.expired?
    self.result_ratio = self.questions.where(correct: true).size.to_f / self.q_count_total.to_f * 100.0
    self.passed = self.passed?
    self.questions.expired.where("#{RmptUserQuestion.table_name}.expired IS NULL").update_all(["#{RmptUserQuestion.table_name}.completed = ?, #{RmptUserQuestion.table_name}.expired = ?", true, true])
    self.questions.uncompleted.update_all(["#{RmptUserQuestion.table_name}.completed = ?", true])
    self.status = get_status
  end

  def complete_step!
    unless self.has_access?
      self.errors.add(:base, l(:error_rmpt_user_test_access_denied))
      return false
    end

    return true if self.completed?

    RmptUserTest.transaction do
      if self.status_blank?
        return false unless self.ensure_start_step!
      end
      self.complete_step
      unless self.save
        raise ActiveRecord::Rollback
      end
    end

    true
  end

  private

  def get_status
    return STATUS_BLANK if self.start_at.blank?
    timelimit_expired = self.expired?

    return STATUS_STARTED if !self.completed? && !timelimit_expired

    if self.passed?
      STATUS_SUCCESS
    elsif timelimit_expired
      STATUS_TIMELIMIT_EXPIRED
    else
      STATUS_FAILED
    end
  end

  def validate_access
    unless self.has_access?
      self.errors.add(:base, l(:error_rmpt_user_test_access_denied))
      return
    end

    if !self.completed? && self.expired?
      self.errors.add(:base, l(:error_rmpt_user_test_timelimit_expired))
    end
  end

  def validate_create_test
    unless self.test.enrolled?(self.user)
      self.errors.add(:base, l(:error_rmpt_user_test_access_denied))
      throw(:abort)
    end

    if self.test.started_user_attempt(self.user).present?
      self.errors.add(:base, l(:error_rmpt_user_test_started))
      throw(:abort)
    end

    unless self.test.has_attempts?(self.user)
      self.errors.add(:base, l(:error_rmpt_user_test_attempts_expired))
      throw(:abort)
    end

    last_attempt = self.test.last_user_attempt(self.user)
    if last_attempt.present? && !self.test.can_retry?(last_attempt)
      left_time = Rmpt::Utils.convert_seconds_to_day_time_string(self.test.retry_time_left(last_attempt), l(:label_rmpt_days_unit_short))

      self.errors.add(:base, l(:error_rmpt_user_test_retry_waiting, time: left_time))
      throw(:abort)
    end
  end
end