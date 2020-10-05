class RmptAnswer < ActiveRecord::Base
  belongs_to :question, class_name: 'RmptQuestion', foreign_key: :question_id, optional: true

  validates :text, :question, presence: true

  def copy_to_user
    RmptUserAnswer.new(text: self.text, correct: self.correct, answer_id: self.id)
  end
end