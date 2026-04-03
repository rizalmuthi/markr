class CreateTestResults < ActiveRecord::Migration[8.1]
  def change
    create_table :test_results do |t|
      t.string :student_number, null: false
      t.string :test_id, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.integer :marks_available, null: false
      t.integer :marks_obtained, null: false
      t.datetime :scanned_on, null: false

      t.timestamps
    end

    add_index :test_results, [:test_id, :student_number], unique: true
  end
end
