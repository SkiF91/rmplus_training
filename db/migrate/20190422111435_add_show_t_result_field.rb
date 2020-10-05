class AddShowTResultField < ActiveRecord::Migration[4.2]
  def change
    add_column :rmpt_tests, :show_t_result, :boolean, default: false
    add_column :rmpt_user_tests, :show_t_result, :boolean, default: false
  end
end