class AddStatusToRmptUserTests < ActiveRecord::Migration[4.2]
  def up
    add_column :rmpt_user_tests, :status, :integer, default: RmptUserTest::STATUS_BLANK

    RmptUserTest.all.each do |ut|
      ut.update_columns(status: ut.send(:get_status))
    end
  end

  def down
    change_column :rmpt_user_tests, :status, :integer
  end
end