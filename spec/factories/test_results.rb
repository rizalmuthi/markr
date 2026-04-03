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

FactoryBot.define do
  factory :test_result do
    student_number { "MyString" }
    test_id { "MyString" }
    first_name { "MyString" }
    last_name { "MyString" }
    marks_available { 1 }
    marks_obtained { 1 }
    scanned_on { "2026-04-03 17:05:49" }
  end
end
