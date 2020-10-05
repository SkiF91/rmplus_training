class RmptTest < ActiveRecord::Base
  include Redmine::SafeAttributes

  has_one :page_pattern, class_name: 'RmptTestsPagePattern', foreign_key: :id, primary_key: :id, dependent: :destroy
  belongs_to :category, class_name: 'RmptCategory', foreign_key: :category_id, optional: true
  belongs_to :author, class_name: 'User', foreign_key: :author_id, optional: true
  belongs_to :group_set, class_name: 'GroupSetRmpt', foreign_key: :group_set_id, dependent: :destroy, optional: true

  has_many :questions, class_name: 'RmptQuestion', foreign_key: :test_id, dependent: :destroy
  has_many :participants, class_name: 'RmptParticipant', foreign_key: :test_id, dependent: :destroy
  has_many :rights, class_name: 'RmptTestRight', foreign_key: :test_id, dependent: :destroy
  has_many :rights_users, through: :rights, source: :user

  has_many :user_tests, class_name: 'RmptUserTest', foreign_key: :test_id, dependent: :destroy
  has_many :extra_attempts, class_name: 'RmptExtraAttempt', foreign_key: :test_id, dependent: :destroy

  accepts_nested_attributes_for :page_pattern

  before_create :store_author
  before_save :ensure_q_count
  after_save :store_participants


  scope :manageable, lambda { |*args|
    user = args[0]
    user ||= User.current
    unless user.global_permission_to?(:rmpt_manage_tests)
      next none
    end

    if user.global_permission_to?(:rmpt_view_all_tests)
      all
    else
      joins("LEFT JOIN
             (
                SELECT r.test_id
                FROM #{RmptTestRight.table_name} r
                WHERE r.user_id = #{user.id.to_i}
                GROUP BY r.test_id
             ) r on r.test_id = #{RmptTest.table_name}.id
            ")
      .where("#{RmptTest.table_name}.author_id = ? OR r.test_id is not null", User.current.id)
    end
  }

  scope :enrolled, lambda { |*args|
    user_id = args[0]
    test_id = args[1]
    user_id = user_id.id if user_id.is_a?(User)
    test_id = test_id.id if test_id.is_a?(RmptTest)
    user_id = user_id.to_i
    test_id = test_id.to_i

    joins("INNER JOIN (
              SELECT eu.id,
                     eu.user_id,
                     eu.enrolled_at as enrolled_date,
                     case when eu.due_days is not null then case when eu.enrolled_at is null then null else #{RmptTest.connection.rmp_get_date(RmptTest.connection.rmp_add_days('eu.enrolled_at', 'eu.due_days'))} end
                          when eu.due_date is not null then eu.due_date
                     else null end as due
              FROM
              (

                SELECT t.id,
                       t.due_date,
                       t.due_days,
                       tu.user_id,
                       MIN(tu.enrolled_at) as enrolled_at
                FROM rmpt_tests t
                     INNER JOIN
                     (
                        SELECT ut.test_id as id,
                               ut.user_id,
                               null as enrolled_at
                        FROM rmpt_user_tests ut
                             INNER JOIN users u on u.id = ut.user_id
                        WHERE u.status = #{User::STATUS_ACTIVE}
                              #{user_id > 0 ? "AND ut.user_id = #{user_id}" : ''}
                              #{test_id > 0 ? "AND ut.test_id = #{test_id}" : ''}
                        GROUP BY ut.test_id, ut.user_id

                        UNION ALL

                        SELECT t.id,
                               u.id as user_id,
                               MIN(case when gs_r.group_set_id = p.group_set_id then p.updated_at else gs_r.updated_at end) as enrolled_at
                        FROM rmpt_tests t
                             LEFT JOIN rmpt_participants p ON p.test_id = t.id
                             INNER JOIN group_sets gs ON gs.id = t.group_set_id OR gs.id = p.group_set_id
                             INNER JOIN group_set_rules gs_r ON gs_r.group_set_id = gs.id
                             INNER JOIN users u ON u.id = gs_r.user_id
                        WHERE u.status = #{User::STATUS_ACTIVE}
                              #{user_id > 0 ? "AND u.id = #{user_id}" : ''}
                              #{test_id > 0 ? "AND t.id = #{test_id}" : ''}
                        GROUP BY t.id, u.id

                        UNION ALL

                        SELECT t.id,
                               u.id as user_id,
                               MIN(case when gs_r.group_set_id = p.group_set_id then p.updated_at else gs_r.updated_at end) as enrolled_at
                        FROM rmpt_tests t
                               LEFT JOIN rmpt_participants p ON p.test_id = t.id
                               INNER JOIN group_sets gs ON gs.id = t.group_set_id OR gs.id = p.group_set_id
                               INNER JOIN group_set_rules gs_r ON gs_r.group_set_id = gs.id
                               INNER JOIN users u ON u.user_title_id = gs_r.user_title_id AND gs_r.user_department_id IS NULL
                        WHERE u.status = #{User::STATUS_ACTIVE}
                              #{user_id > 0 ? "AND u.id = #{user_id}" : ''}
                              #{test_id > 0 ? "AND t.id = #{test_id}" : ''}
                        GROUP BY t.id, u.id

                        UNION ALL

                        SELECT t.id,
                               u.id as user_id,
                               MIN(case when gs_r.group_set_id = p.group_set_id then p.updated_at else gs_r.updated_at end) as enrolled_at
                        FROM rmpt_tests t
                               LEFT JOIN rmpt_participants p ON p.test_id = t.id
                               INNER JOIN group_sets gs ON gs.id = t.group_set_id OR gs.id = p.group_set_id
                               INNER JOIN group_set_rules gs_r ON gs_r.group_set_id = gs.id
                               INNER JOIN user_department_trees dt on dt.id = gs_r.user_department_id
                               INNER JOIN user_department_trees _dt on _dt.lft >= dt.lft and _dt.rgt <= dt.rgt
                               INNER JOIN users u ON u.user_department_id = _dt.id AND gs_r.user_title_id IS NULL
                        WHERE u.status = #{User::STATUS_ACTIVE}
                              #{user_id > 0 ? "AND u.id = #{user_id}" : ''}
                              #{test_id > 0 ? "AND t.id = #{test_id}" : ''}
                        GROUP BY t.id, u.id

                        UNION ALL

                        SELECT t.id,
                               u.id as user_id,
                               MIN(case when gs_r.group_set_id = p.group_set_id then p.updated_at else gs_r.updated_at end) as enrolled_at
                        FROM rmpt_tests t
                                LEFT JOIN rmpt_participants p ON p.test_id = t.id
                                INNER JOIN group_sets gs ON gs.id = t.group_set_id OR gs.id = p.group_set_id
                                INNER JOIN group_set_rules gs_r ON gs_r.group_set_id = gs.id
                                INNER JOIN user_department_trees dt on dt.id = gs_r.user_department_id
                                INNER JOIN user_department_trees _dt on _dt.lft >= dt.lft and _dt.rgt <= dt.rgt
                                INNER JOIN users u ON u.user_department_id = _dt.id AND u.user_title_id = gs_r.user_title_id
                        WHERE u.status = #{User::STATUS_ACTIVE}
                              #{user_id > 0 ? "AND u.id = #{user_id}" : ''}
                              #{test_id > 0 ? "AND t.id = #{test_id}" : ''}
                        GROUP BY t.id, u.id
                     ) tu on tu.id = t.id
                GROUP BY t.id, t.due_date, t.due_days, tu.user_id
              ) eu
          ) st on st.id = #{RmptTest.table_name}.id
          INNER JOIN #{User.table_name} u ON u.id = st.user_id
          ")
    .where('u.status = ?', User::STATUS_ACTIVE)
    .select("#{RmptTest.table_name}.*, st.user_id, st.enrolled_date, st.due")
  }

  scope :enrolled_with_attempts_info, lambda { |*args|
    user = args[0]

    enrolled(user)
    .joins("LEFT JOIN (
                SELECT ut.user_id,
                       ut.test_id,
                       COUNT(1) as cnt,
                       MAX(ut.result_ratio) as max_result_ratio,
                       MAX(case when ut.completed = #{RmptTest.connection.quoted_true} then 1 else 0 end) as max_completed,
                       MAX(case when ut.passed = #{RmptTest.connection.quoted_true} then 1 else 0 end) as max_passed,
                       MIN(ut.status) as min_status
                FROM #{RmptUserTest.table_name} ut
                GROUP BY ut.user_id, ut.test_id
            ) c_ut ON c_ut.test_id = #{RmptTest.table_name}.id and c_ut.user_id = u.id
            LEFT JOIN (
              SELECT a.test_id,
                     a.user_id,
                     SUM(a.attempts) as attempts
              FROM #{RmptExtraAttempt.table_name} a
              GROUP BY a.test_id, a.user_id
            ) ex_att ON ex_att.test_id = #{RmptTest.table_name}.id and ex_att.user_id = u.id
            LEFT JOIN (
              SELECT tr.test_id
              FROM #{RmptTestRight.table_name} tr
              WHERE tr.user_id = #{User.current.id}
            ) has_r ON has_r.test_id = #{RmptTest.table_name}.id")
    .select("c_ut.cnt as attempts_used,
             c_ut.max_result_ratio,
             c_ut.min_status,
             COALESCE(c_ut.max_completed, 0) as max_completed,
             COALESCE(c_ut.max_passed, 0) as max_passed,
             COALESCE(ex_att.attempts, 0) as extra_attempts,
             case when #{RmptTest.table_name}.author_id = #{User.current.id} OR has_r.test_id is not null then 1 else 0 end as t_manageable
            ")
  }

  scope :my_filtered, lambda { |user, filter|
    base_scope = enrolled_with_attempts_info(user)
    filter = 'on_me' unless %w(on_me actual completed overdue failed).include?(filter)

    case filter
      when 'on_me', 'actual'
        base_scope.where("(c_ut.test_id is null OR c_ut.max_passed = 0)
                      AND (#{RmptTest.table_name}.attempts is null OR c_ut.test_id is null OR c_ut.cnt < #{RmptTest.table_name}.attempts + COALESCE(ex_att.attempts, 0))
                      AND (st.due is null OR st.due >= ?)
                         ", Date.today)
      when 'overdue'
        base_scope.where("(c_ut.test_id is null OR c_ut.max_passed = 0)
                      AND (#{RmptTest.table_name}.attempts is null OR c_ut.test_id is null OR c_ut.cnt < #{RmptTest.table_name}.attempts + COALESCE(ex_att.attempts, 0))
                      AND (st.due is not null AND st.due < ?)", Date.today)
      when 'failed'
        base_scope.where("(c_ut.test_id is null OR c_ut.max_passed = 0)
                     AND #{RmptTest.table_name}.attempts is not null
                     AND c_ut.cnt >= #{RmptTest.table_name}.attempts + COALESCE(ex_att.attempts, 0)")
      when 'completed'
        base_scope.where('c_ut.max_passed = 1')
      else
        base_scope
    end
  }

  validate :validate_access
  validates :name, presence: true, if: :valid_access?
  validates_length_of :name, maximum: 255, if: :valid_access?

  include Rmpt::Testable

  safe_attributes 'id', unsafe: true

  def self.enrolled_users(user = User.current)
    User.joins("INNER JOIN (#{RmptTest.manageable(user).enrolled.to_sql}) et ON et.user_id = #{User.table_name}.id").distinct
  end

  def manageable?(user = User.current)
    if self.new_record?
      user.global_permission_to?(:rmpt_manage_tests)
    else
      return true if user.global_permission_to?(:rmpt_manage_tests) && user.global_permission_to?(:rmpt_view_all_tests)
      if self.attributes.has_key?('t_manageable')
        user.global_permission_to?(:rmpt_manage_tests) && self.attributes['t_manageable'].to_i == 1
      else
        user.global_permission_to?(:rmpt_manage_tests) && (self.author_id == user.id || self.rights.map(&:user_id).include?(user.id))
      end
    end
  end

  def enrolled?(user = User.current)
    !self.new_record? && RmptTest.enrolled(user, self).present?
  end

  def startable?(user = User.current)
    return false if !self.enrolled?(user) || !self.started_user_attempt(user).blank?
    return false unless self.has_attempts?(user)
    last_attempt = self.last_user_attempt(user)
    last_attempt.blank? || self.can_retry?(last_attempt)
  end

  def user_attempts(user = User.current)
    self.user_tests.where(user_id: user.id).order(Arel.sql("case when completed = #{RmptTest.connection.quoted_true} then 1 else 0 end ASC"))
  end

  def user_extra_attempts(user = User.current)
    self.extra_attempts.where(user_id: user.id).sum(:attempts).to_i
  end

  def last_user_attempt(user = User.current)
    self.user_attempts(user).order(id: :desc).first
  end

  def started_user_attempt(user = User.current)
    self.user_tests.actual(user).first
  end

  def copy_to_user(user = User.current)
    user_test = RmptUserTest.new(test: self, user: user)
    %w(min_pass min_pass_percent timelimit_total timelimit_q show_q_result show_t_result can_skip can_resubmit).each do |field|
      user_test.send("#{field}=", self.send(field))
    end

    target_questions = self.questions.order(:position).to_a
    if self.randomize?
      target_questions = target_questions.shuffle
    end
    if self.q_count.to_i > 0 && self.q_count < target_questions.size
      target_questions = target_questions.take(self.q_count)
    end

    user_test.q_count_total = target_questions.size
    q_num = 0
    user_test.questions = target_questions.map do |q|
      tq = q.copy_to_user
      q_num += 1
      tq.num = q_num
      tq
    end

    user_test
  end

  def copy_to_user!(user = User.current)
    user_test = self.copy_to_user(user)
    user_test.save

    user_test
  end

  def can_retry?(last_try)
    self.retry_time_left(last_try) == 0
  end

  def retry_time_left(last_try)
    return 0 if last_try.blank? || self.retrying_delay.blank?
    return nil if [RmptUserTest::STATUS_BLANK, RmptUserTest::STATUS_STARTED].include?(last_try.status)

    date_at = last_try.end_at || last_try.start_at
    return nil if date_at.blank?

    seconds_left = (Time.now - date_at).to_i
    if seconds_left > self.retrying_delay.to_i
      0
    else
      self.retrying_delay.to_i - seconds_left
    end
  end

  def total_attempts(user=User.current)
    return nil if self.attempts.blank?

    if self.attributes.has_key?('extra_attempts')
      self.attempts + self.attributes['extra_attempts'].to_i
    else
      return self.attempts if user.blank?
      self.attempts + self.user_extra_attempts(user).to_i
    end
  end

  def has_attempts?(user=User.current)
    return true if self.attempts.blank?
    if self.attributes.has_key?('attempts_used')
      used = self.attributes['attempts_used'].to_i
    else
      used = self.user_attempts(user).size
    end
    self.total_attempts(user) > used
  end



  def retrying_delay_parted
    return { days: '', time: '' } if self.retrying_delay.blank?

    days = (self.retrying_delay.to_f / 86400.0).to_i

    time = self.retrying_delay.to_i - (days * 86400)
    return { days: days == 0 ? nil : days, time: nil } if time <= 0

    { days: days == 0 ? nil : days, time: Rmpt::Utils.convert_seconds_to_time_string(time) }
  end

  def retrying_delay_parted=(parts)
    if parts.blank? || !parts.is_a?(Hash) || parts[:days].blank? && parts[:time].blank?
      self.retrying_delay = nil
    else
      seconds = parts[:days].to_i * 86400

      if parts[:time].blank?
        self.retrying_delay = seconds
      else
        self.retrying_delay = seconds + Time.parse(parts[:time]).seconds_since_midnight
      end
    end
  end

  def due_date=(value)
    if value.present?
      self.due_days = nil
    end

    write_attribute :due_date, value
  end

  def due_days=(value)
    if value.present?
      self.due_date = nil
    end

    write_attribute :due_days, value
  end

  def group_set_attributes=(rules)
    fill_default_group_set
    if self.group_set.new_record?
      self.group_set.rules_attributes = rules
    else
      del_ids = rules[:del_ids]
      self.group_set.rules_append_attributes = rules
      if del_ids.present?
        self.group_set.rules_delete_ids = del_ids
      end
    end
  end

  def appended_participants
    @appended_participants
  end

  def participants_append_attributes=(groupsets)
    if groupsets.respond_to?(:to_unsafe_hash)
      groupsets = groupsets.to_unsafe_hash
    end
    @new_participants = self.participants.to_a
    @appended_participants = []
    @was_participants_assigned = true
    groupsets.each do |gs|
      gs = gs[1] if gs.is_a?(Array)
      ex_gs = self.participants.detect { |p| p.group_set_id == gs[:groupset_id] }
      gs = (ex_gs || RmptParticipant.new(test: self, group_set_id: gs[:groupset_id]))
      @new_participants << gs
      @appended_participants << gs
    end
  end

  def participants_delete_ids=(ids)
    return if ids.blank?
    @new_participants ||= self.participants.to_a
    @was_participants_assigned = true

    ids = Array.wrap(ids).map(&:to_i)
    del_p = self.participants.select { |p| ids.include?(p.id) }
    @new_participants -= del_p
  end

  def fill_default_page_patterns
    if self.page_pattern.blank?
      self.page_pattern = self.build_page_pattern(
          start_text: l(:text_rmpt_tests_page_pattern_start_default),
          retry_text: l(:text_rmpt_tests_page_pattern_retry_default),
          success_text: l(:text_rmpt_tests_page_pattern_success_default),
          fail_text: l(:text_rmpt_tests_page_pattern_fail_default)
      )
    end
  end

  def fill_default_group_set
    if self.group_set.blank?
      self.group_set = self.build_group_set(test: self, name: "RMPT")
    end
  end

  def save(*args)
    self.fill_default_page_patterns
    self.fill_default_group_set

    super
  end

  private

  def store_author
    self.author = User.current
  end

  def ensure_q_count
    if self.q_count.present? && (self.q_count < 0 || self.q_count > self.questions.size)
      self.q_count = nil
    end
  end

  def validate_access
    unless self.manageable?
      self.errors.add(:base, l(:error_rmpt_test_access_denied))
    end
  end

  def valid_access?
    self.errors.blank?
  end

  def store_participants
    if @was_participants_assigned
      self.participants.reload
      self.participants = @new_participants || []
      @new_participants = nil
    end
  end
end