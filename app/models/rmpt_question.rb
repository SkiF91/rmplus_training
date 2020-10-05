class RmptQuestion < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :test, class_name: 'RmptTest', foreign_key: :test_id, optional: true
  has_many :answers, class_name: 'RmptAnswer', foreign_key: :question_id, dependent: :destroy

  validate :validate_access
  validates :text, :test, presence: true, if: :valid_access?
  validate :validate_answers, if: :valid_access?

  before_save :store_position

  scope :sorted, -> { order("#{RmptQuestion.table_name}.position") }

  QTYPE_SINGLE = 0
  QTYPE_MULTIPLE = 1

  acts_as_attachable

  include Rmpt::Questionable

  safe_attributes 'id', unsafe: true

  def attachments_visible?(user=User.current)
    true
  end
  def attachments_deletable?(user=User.current)
    true
  end
  def attachments_editable?(user=User.current)
    true
  end

  def can_clear_stat?
    self.count_touch.present? && self.time_touch.present? && self.correct_count.present?
  end

  def copy_to_user
    uq = RmptUserQuestion.new(text: self.text, qtype: self.qtype, question_id: self.id)
    uq.attachments = self.attachments.map(&:dup)
    uq.attachments.each do |a|
      a.container = uq
    end
    uqa = self.dirty_answers.to_a

    if self.randomize?
      uqa = uqa.shuffle
    end

    num = 0
    uq.answers = uqa.map do |a|
      ta = a.copy_to_user
      num += 1
      ta.num = num
      ta
    end

    uq
  end


  private

  def validate_answers
    if (@was_answer_assign && @answers.blank?) || (!@was_answer_assign && self.answers.blank?)
      self.errors.add(:base, l(:error_rmpt_q_answers_blank))
    end

    if @answers.present?
      answ_errors = []
      correct = false

      @answers.each do |answ|
        correct ||= answ.correct?
        next if answ.valid?
        answ.errors.full_messages.each do |err|
          answ_errors << err
        end
      end

      (self.errors.add(:base, l(:rmpt_error_not_have_correct_answer))) unless correct

      answ_errors.uniq.each do |err|
        self.errors.add(:base, err)
      end
    end
  end

  def validate_access
    if self.test.present? && !self.test.manageable?
      self.errors.add(:base, l(:error_rmpt_q_access_denied))
    end
  end

  def store_position
    if self.new_record?
      self.position = self.test.questions.size
    end
  end

  def valid_access?
    self.errors.blank?
  end
end