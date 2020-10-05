class AddQuestionIdToUserQuestions < ActiveRecord::Migration[4.2]
  def change
    add_column :rmpt_user_questions, :question_id, :integer, null: true
  end
end