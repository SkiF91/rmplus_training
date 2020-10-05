class CreateRmptExtraAttempts < ActiveRecord::Migration[4.2]
  def change
    create_table :rmpt_extra_attempts do |t|
      t.integer :test_id, null: false
      t.integer :user_id, null: false
      t.integer :attempts, null: false
    end

    add_index :rmpt_extra_attempts, [:test_id, :user_id], unique: false
  end
end