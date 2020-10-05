class RmptUserAnswer < ActiveRecord::Base
  belongs_to :question, class_name: 'RmptUserQuestion', foreign_key: :question_id, optional: true
end