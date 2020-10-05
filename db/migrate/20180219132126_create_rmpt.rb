class CreateRmpt < ActiveRecord::Migration[4.2]
  def change
    create_table :rmpt_categories do |t|
      t.string :name, null: false
      t.integer :parent_id
      t.integer :lft
      t.integer :rgt
    end

    add_index :rmpt_categories, [:parent_id], name: 'index_rmpt_categories_p', unique: false
    add_index :rmpt_categories, [:lft, :rgt], name: 'index_rmpt_categories_lr', unique: false

    create_table :rmpt_tests do |t|
      t.string :name, null: false
      t.integer :author_id, null: false
      t.integer :category_id
      t.integer :group_set_id
      t.boolean :archived

      t.integer :q_count

      t.integer :min_pass
      t.float :min_pass_percent

      t.integer :timelimit_total
      t.integer :timelimit_q

      t.integer :attempts

      t.date :due_date
      t.integer :due_days

      t.integer :retrying_delay

      t.boolean :show_q_result
      t.boolean :randomize
      t.boolean :can_skip
      t.boolean :can_resubmit
    end

    add_index :rmpt_tests, [:category_id], unique: false

    create_table :rmpt_tests_page_patterns, id: false do |t|
      t.integer :id, null: false
      t.text :start_text
      t.text :retry_text
      t.text :success_text
      t.text :fail_text

      t.primary_key :id
    end

    create_table :rmpt_questions do |t|
      t.integer :test_id, null: false
      t.integer :position
      t.text :text
      t.integer :qtype
      t.boolean :randomize
    end

    add_index :rmpt_questions, [:test_id], unique: false

    create_table :rmpt_answers do |t|
      t.integer :question_id
      t.string :text
      t.boolean :correct, default: false
    end

    add_index :rmpt_answers, [:question_id], unique: false


    create_table :rmpt_participants do |t|
      t.integer :test_id, null: false
      t.integer :group_set_id, null: false

      t.timestamps
    end

    add_index :rmpt_participants, [:test_id], unique: false
    add_index :rmpt_participants, [:group_set_id], unique: false
    add_index :rmpt_participants, [:test_id, :group_set_id], name: 'index_rmpt_participants_tg', unique: true

    create_table :rmpt_test_rights do |t|
      t.integer :test_id, null: false
      t.integer :user_id, null: false
    end

    add_index :rmpt_test_rights, [:test_id], unique: false
    add_index :rmpt_test_rights, [:user_id], unique: false
    add_index :rmpt_test_rights, [:test_id, :user_id], name: 'index_rmpt_test_rights_tu', unique: true
  end
end