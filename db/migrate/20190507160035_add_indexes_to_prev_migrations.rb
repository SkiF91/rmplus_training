class AddIndexesToPrevMigrations < ActiveRecord::Migration[4.2]
  def change
    add_index :rmpt_user_questions, :question_id, unique: false
    add_index :rmpt_user_answers, :answer_id, unique: false
  end
end