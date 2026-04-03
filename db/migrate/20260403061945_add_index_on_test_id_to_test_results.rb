class AddIndexOnTestIdToTestResults < ActiveRecord::Migration[8.1]
  def change
    add_index :test_results, :test_id
  end
end
