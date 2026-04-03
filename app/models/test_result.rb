# == Schema Information
#
# Table name: test_results
#
#  id              :integer          not null, primary key
#  student_number  :string           not null
#  test_id         :string           not null
#  first_name      :string           not null
#  last_name       :string           not null
#  marks_available :integer          not null
#  marks_obtained  :integer          not null
#  scanned_on      :datetime         not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_test_results_on_test_id                     (test_id)
#  index_test_results_on_test_id_and_student_number  (test_id,student_number) UNIQUE
#

class TestResult < ApplicationRecord
  validates :student_number, presence: true
  validates :test_id, presence: true
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :scanned_on, presence: true
  validates :marks_available, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :marks_obtained, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :student_number, uniqueness: { scope: :test_id }

  validate :obtained_not_exceeding_available

  def self.upsert_results(results)
    return if results.empty?

    now = Time.current

    rows = results.map do |result|
      {
        student_number: result[:student_number],
        test_id: result[:test_id],
        first_name: result[:first_name],
        last_name: result[:last_name],
        marks_available: result[:marks_available],
        marks_obtained: result[:marks_obtained],
        scanned_on: result[:scanned_on],
        created_at: now,
        updated_at: now
      }
    end

    upsert_all(
      rows,
      unique_by: [:test_id, :student_number],
      on_duplicate: Arel.sql(<<~SQL.squish)
        marks_obtained = GREATEST(test_results.marks_obtained, EXCLUDED.marks_obtained),
        marks_available = GREATEST(test_results.marks_available, EXCLUDED.marks_available),
        updated_at = EXCLUDED.updated_at
      SQL
    )
  end

  private

  def obtained_not_exceeding_available
    return unless marks_obtained && marks_available

    if marks_obtained > marks_available
      errors.add(:marks_obtained, "cannot exceed marks available")
    end
  end
end
