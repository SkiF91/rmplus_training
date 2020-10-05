class AddStatFieldsToQuestions < ActiveRecord::Migration[4.2]
  def change
    add_column :rmpt_user_questions, :entered_at, :datetime, null: true
    add_column :rmpt_questions, :correct_count, :integer, null: true
    add_column :rmpt_questions, :time_touch, :integer, null: true
    add_column :rmpt_questions, :count_touch, :integer, null: true
  end
end