class AddStatFieldToAnswers < ActiveRecord::Migration[4.2]
  def change
    add_column :rmpt_user_answers, :answer_id, :integer, null: true
    add_column :rmpt_answers, :count_touch, :integer, null: true
  end
end