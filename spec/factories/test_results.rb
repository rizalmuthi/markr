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
