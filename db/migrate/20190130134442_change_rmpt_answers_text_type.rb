class ChangeRmptAnswersTextType < ActiveRecord::Migration[4.2]
  def up
    change_column :rmpt_answers, :text, :text, limit: 16777214
    change_column :rmpt_user_answers, :text, :text, limit: 16777214
  end
end