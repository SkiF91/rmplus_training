class CreateUserRmptObjects < ActiveRecord::Migration[4.2]
  def change
    create_table :rmpt_user_tests do |t|
      t.integer :test_id, null: false
      t.integer :user_id, null: false
      t.datetime :start_at
      t.datetime :end_at

      t.integer :min_pass
      t.float :min_pass_percent
      t.integer :timelimit_total
      t.integer :timelimit_q
      t.boolean :show_q_result, default: false
      t.boolean :can_skip, default: false
      t.boolean :can_resubmit, default: false

      t.integer :q_count_total

      t.integer :q_count_correct
      t.datetime :last_q_touch_at
      t.integer :q_count_touch
      t.float :result_ratio
      t.boolean :passed
      t.boolean :completed, default: false
      t.boolean :expired
    end

    add_index :rmpt_user_tests, [:test_id, :user_id], unique: false

    create_table :rmpt_user_questions do |t|
      t.integer :test_id, null: false
      t.integer :num, null: false
      t.text :text
      t.integer :qtype

      t.boolean :correct
      t.datetime :start_at
      t.datetime :end_at
      t.boolean :completed, default: false
      t.boolean :expired
    end

    add_index :rmpt_user_questions, [:test_id], unique: false
    add_index :rmpt_user_questions, [:test_id, :num], unique: false

    create_table :rmpt_user_answers do |t|
      t.integer :question_id, null: false
      t.integer :num, null: false
      t.string :text
      t.boolean :correct, default: false

      t.boolean :selected, default: false
    end

    add_index :rmpt_user_answers, [:question_id], unique: false
    add_index :rmpt_user_answers, [:question_id, :num], unique: false
  end
end