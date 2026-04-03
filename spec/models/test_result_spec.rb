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

require 'rails_helper'

RSpec.describe TestResult, type: :model do
  describe "validations" do
    subject { build(:test_result) }

    it { is_expected.to be_valid }

    it "requires student_number" do
      subject.student_number = nil

      expect(subject).not_to be_valid
    end

    it "requires test_id" do
      subject.test_id = nil

      expect(subject).not_to be_valid
    end

    it "requires first_name" do
      subject.first_name = nil

      expect(subject).not_to be_valid
    end

    it "requires last_name" do
      subject.last_name = nil

      expect(subject).not_to be_valid
    end

    it "requires marks_available to be positive" do
      subject.marks_available = 0

      expect(subject).not_to be_valid
    end

    it "requires marks_obtained to be non-negative" do
      subject.marks_obtained = -1

      expect(subject).not_to be_valid
    end

    it "rejects marks_obtained exceeding marks_available" do
      subject.marks_obtained = 25
      subject.marks_available = 20

      expect(subject).not_to be_valid
      expect(subject.errors[:marks_obtained]).to include("cannot exceed marks available")
    end

    it "enforces uniqueness of student_number scoped to test_id" do
      create(:test_result, student_number: "STU001", test_id: "1234")
      duplicate = build(:test_result, student_number: "STU001", test_id: "1234")

      expect(duplicate).not_to be_valid
    end

    it "allows same student_number for different test_ids" do
      create(:test_result, student_number: "STU001", test_id: "1234")
      different_test = build(:test_result, student_number: "STU001", test_id: "5678")

      expect(different_test).to be_valid
    end
  end
end
