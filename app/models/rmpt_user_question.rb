class RmptUserQuestion < ActiveRecord::Base
  belongs_to :test, class_name: 'RmptUserTest', foreign_key: :test_id, inverse_of: :questions, optional: true

  has_many :answers, class_name: 'RmptUserAnswer', foreign_key: :question_id, dependent: :destroy
  belongs_to :question, class_name: 'RmptQuestion', foreign_key: :question_id, optional: true

  acts_as_attachable

  include Rmpt::Questionable

  scope :uncompleted, -> {
    where(completed: false)
  }

  scope :actual, -> {
    joins(:test)
    .where("#{RmptUserTest.table_name}.expired = ? OR #{RmptUserTest.table_name}.expired is null", false)
    .where("#{RmptUserTest.table_name}.completed = ?", false)
    .where("#{RmptUserTest.table_name}.timelimit_q is null OR #{RmptUserQuestion.table_name}.start_at is null OR #{RmptTest.connection.rmp_seconds_diff("#{RmptUserQuestion.table_name}.start_at", "COALESCE(#{RmptUserQuestion.table_name}.end_at, #{RmptTest.connection.quote(RmptTest.connection.quoted_date(Time.now))})")} - #{RmptUserTest::SECONDS_LAG} <= #{RmptUserTest.table_name}.timelimit_q")
  }

  scope :expired, -> {
    joins(:test)
    .where("#{RmptUserTest.table_name}.expired = ?", true)
    .where("#{RmptUserTest.table_name}.completed = ?", false)
    .where("#{RmptUserTest.table_name}.timelimit_q is not null AND #{RmptUserQuestion.table_name}.start_at is not null AND #{RmptTest.connection.rmp_seconds_diff("#{RmptUserQuestion.table_name}.start_at", "COALESCE(#{RmptUserQuestion.table_name}.end_at, #{RmptTest.connection.quote(RmptTest.connection.quoted_date(Time.now))})")} - #{RmptUserTest::SECONDS_LAG} > #{RmptUserTest.table_name}.timelimit_q")
  }

  def attachments_visible?(user=User.current)
    true
  end
  def attachments_deletable?(user=User.current)
    false
  end
  def attachments_editable?(user=User.current)
    false
  end

  def touched?
    self.start_at.present?
  end

  def can_submit?
    !self.completed? || self.test.can_resubmit?
  end

  def expired?(use_lag=true)
    if @skip_expired_check
      @skip_expired_check = false
      return false
    end
    return self.expired unless self.expired.nil?
    return false if self.test.timelimit_q.blank? || !self.touched?
    if use_lag
      self.timelimit_left + RmptUserTest::SECONDS_LAG <= 0
    else
      self.timelimit_left <= 0
    end
  end

  def calc_expired?
    exp = self.expired?(false)
    return true if exp
    return false if self.test.timelimit_q.blank? || !self.touched?
    self.test.timelimit_q - self.time_used(nil) <= 0
  end

  def time_used(end_date=self.end_at)
    ((end_date || Time.now) - (self.start_at || Time.now)).to_i
  end

  def timelimit_left(end_date=self.end_at)
    return if self.test.timelimit_q.blank?
    self.test.timelimit_q - self.time_used(end_date)
  end

  def selectable?
    return false if self.calc_expired?
    return false unless self.can_submit?
    self.test.can_skip? || (self.test.can_resubmit? && (self.completed? || self.touched?))
  end

  def can_answer?
    return false if self.expired?
    return false unless self.can_submit?

    return true if self.test.can_skip?
    return true if self.test.can_resubmit? && self.completed?
    return true if self.num == 1

    prev = self.test.question_by_num(self.num - 1)
    prev.blank? || prev.completed? || prev.expired?
  end

  def ensure_touched
    unless self.touched?
      self.start_at = Time.now
    end
  end

  def touch_step!
    return false unless self.validate_step

    self.ensure_touched
    self.entered_at = Time.now
    if self.end_at.present?
      self.end_at = nil
    end
    self.expired = nil
    self.save
  end

  def store_step!(params={})
    @skip_expired_check = true
    return false unless self.validate_step

    self.ensure_touched

    was_completed = self.completed?
    was_correct = self.correct?

    self.completed = true

    if self.expired?
      self.correct = false if self.correct.nil?
      self.expired = true
    else
      self.expired = self.expired?(false)
      self.end_at = Time.now
      unless params[:timeout]
        nums = Array.wrap(params[:answer]).map(&:to_i) + [0]
        old_ids, cur_ids, nums_ids  = [], [],{}

        self.answers.each do |a|
          old_ids << a.answer_id if a.selected?
          nums_ids[a.num] = a.answer_id
        end
        nums.each{ |n| cur_ids << nums_ids[n] }

        res_ids = cur_ids + old_ids - (cur_ids & old_ids)
        cur_ids = (cur_ids + [0] - [nil, '']).join(',')
        old_ids = (old_ids + [0] - [nil]).join(',')

        self.answers.update_all(['selected = case when num IN (?) then ? else ? end', nums, true, false])
        # Обновить счетчик у ответов для статистики
        RmptAnswer.where(id: res_ids).update_all(["count_touch = CASE WHEN id IN(#{old_ids}) THEN count_touch - 1
                     WHEN id IN(#{cur_ids}) THEN COALESCE(count_touch, 0) + 1
                     ELSE count_touch
                     END"])
      end
      self.correct = self.answers.where('correct <> selected').blank?
    end
    @skip_expired_check = true
    unless self.save
      raise ActiveRecord::Rollback
    end

    # Обновить счетчики у вопроса для статистики
    q = self.question
    if q.present?
      for_q_time = 0
      if self.end_at.present?
        for_q_time = self.end_at - self.entered_at
      end

      if self.correct? && !was_correct
        q.correct_count = q.correct_count.present? ? q.correct_count + 1 : 1
      elsif was_correct && !self.correct?
        q.correct_count = q.correct_count.present? ? q.correct_count - 1 : nil
      end

      unless was_completed
        q.count_touch = q.count_touch.present? ? q.count_touch + 1 : 1
      end

      q.time_touch = q.time_touch.present? ? q.time_touch + for_q_time : for_q_time

      q.update_columns(time_touch: q.time_touch, count_touch: q.count_touch, correct_count: q.correct_count) if q.changed?
    end

    if self.expired?
      self.errors.add(:base, l(:error_rmpt_user_question_expired))
      return false
    end
    true
  end

  def validate_step
    if self.expired?
      self.errors.add(:base, l(:error_rmpt_user_question_expired))
      return false
    end
    unless self.can_submit?
      self.errors.add(:base, l(:error_rmpt_user_question_resubmit_prohibited))
      return false
    end

    if !self.expired? && !self.can_answer?
      self.errors.add(:base, l(:error_rmpt_user_question_skip_prohibited))
      return false
    end
    true
  end
end