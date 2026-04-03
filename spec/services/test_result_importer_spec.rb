require "rails_helper"

RSpec.describe TestResultImporter do
  def build_xml(results_xml)
    <<~XML
      <?xml version="1.0" encoding="UTF-8" ?>
      <mcq-test-results>
        #{results_xml}
      </mcq-test-results>
    XML
  end

  def single_result_xml(overrides = {})
    fields = {
      "first-name" => "Jane",
      "last-name" => "Austen",
      "student-number" => "521585128",
      "test-id" => "1234",
      "summary-marks" => '<summary-marks available="20" obtained="13" />'
    }.merge(overrides)

    result_body = fields.map do |key, value|
      next value if key == "summary-marks"
      "<#{key}>#{value}</#{key}>"
    end.join("\n")

    <<~XML
      <mcq-test-result scanned-on="2017-12-04T12:12:10+11:00">
        #{result_body}
      </mcq-test-result>
    XML
  end

  describe "#import!" do
    it "imports valid XML with one result" do
      xml = build_xml(single_result_xml)
      importer = described_class.new(xml)

      expect { importer.import! }.to change(TestResult, :count).by(1)

      result = TestResult.last
      expect(result.student_number).to eq("521585128")
      expect(result.test_id).to eq("1234")
      expect(result.first_name).to eq("Jane")
      expect(result.last_name).to eq("Austen")
      expect(result.marks_available).to eq(20)
      expect(result.marks_obtained).to eq(13)
    end

    it "imports multiple results in one document" do
      xml = build_xml(
        single_result_xml("student-number" => "STU001") +
        single_result_xml("student-number" => "STU002")
      )

      expect { described_class.new(xml).import! }.to change(TestResult, :count).by(2)
    end

    it "returns the count of results processed" do
      xml = build_xml(
        single_result_xml("student-number" => "STU001") +
        single_result_xml("student-number" => "STU002")
      )

      count = described_class.new(xml).import!
      expect(count).to eq(2)
    end

    it "handles duplicates within the same document by keeping the highest score" do
      xml = build_xml(
        single_result_xml("student-number" => "STU001", "summary-marks" => '<summary-marks available="20" obtained="10" />') +
        single_result_xml("student-number" => "STU001", "summary-marks" => '<summary-marks available="20" obtained="15" />')
      )

      described_class.new(xml).import!

      result = TestResult.find_by(student_number: "STU001")
      expect(result.marks_obtained).to eq(15)
    end

    it "handles empty mcq-test-results element" do
      xml = build_xml("")
      expect { described_class.new(xml).import! }.not_to change(TestResult, :count)
    end

    context "with a large document" do
      it "imports 500 results from a single XML document" do
        results_xml = 500.times.map do |i|
          single_result_xml(
            "student-number" => "STU#{i.to_s.rjust(6, '0')}",
            "summary-marks" => %(<summary-marks available="100" obtained="#{i % 101}" />)
          )
        end.join

        xml = build_xml(results_xml)
        count = described_class.new(xml).import!

        expect(count).to eq(500)
        expect(TestResult.count).to eq(500)
      end
    end

    context "with malformed XML" do
      it "raises MalformedXmlError for invalid XML syntax" do
        expect {
          described_class.new("<not valid xml<>").import!
        }.to raise_error(TestResultImporter::MalformedXmlError)
      end

      it "raises MalformedXmlError for wrong root element" do
        xml = '<?xml version="1.0" ?><wrong-root><item/></wrong-root>'
        expect {
          described_class.new(xml).import!
        }.to raise_error(TestResultImporter::MalformedXmlError, /Root element/)
      end
    end

    context "with missing required fields" do
      it "rejects document missing student-number" do
        xml = build_xml(single_result_xml.gsub(/<student-number>.*<\/student-number>/, ""))

        expect {
          described_class.new(xml).import!
        }.to raise_error(TestResultImporter::InvalidDocumentError, /student-number/)
      end

      it "rejects document missing test-id" do
        xml = build_xml(single_result_xml.gsub(/<test-id>.*<\/test-id>/, ""))

        expect {
          described_class.new(xml).import!
        }.to raise_error(TestResultImporter::InvalidDocumentError, /test-id/)
      end

      it "rejects document missing first-name" do
        xml = build_xml(single_result_xml.gsub(/<first-name>.*<\/first-name>/, ""))

        expect {
          described_class.new(xml).import!
        }.to raise_error(TestResultImporter::InvalidDocumentError, /first-name/)
      end

      it "rejects document missing last-name" do
        xml = build_xml(single_result_xml.gsub(/<last-name>.*<\/last-name>/, ""))

        expect {
          described_class.new(xml).import!
        }.to raise_error(TestResultImporter::InvalidDocumentError, /last-name/)
      end

      it "rejects document missing summary-marks" do
        xml = build_xml(single_result_xml("summary-marks" => ""))

        expect {
          described_class.new(xml).import!
        }.to raise_error(TestResultImporter::InvalidDocumentError, /summary-marks/)
      end

      it "does not partially import when one result is invalid" do
        xml = build_xml(
          single_result_xml("student-number" => "STU001") +
          single_result_xml("student-number" => "").gsub(/<student-number><\/student-number>/, "")
        )

        expect {
          begin
            described_class.new(xml).import!
          rescue TestResultImporter::InvalidDocumentError
          end
        }.not_to change(TestResult, :count)
      end
    end

    context "with marks values" do
      it "rejects non-integer marks-available" do
        xml = build_xml(
          single_result_xml("summary-marks" => '<summary-marks available="abc" obtained="13" />')
        )

        expect {
          described_class.new(xml).import!
        }.to raise_error(TestResultImporter::InvalidDocumentError, /Invalid integer value/)
      end

      it "rejects non-integer marks-obtained" do
        xml = build_xml(
          single_result_xml("summary-marks" => '<summary-marks available="20" obtained="twelve" />')
        )

        expect {
          described_class.new(xml).import!
        }.to raise_error(TestResultImporter::InvalidDocumentError, /Invalid integer value/)
      end

      it "rejects float marks values" do
        xml = build_xml(
          single_result_xml("summary-marks" => '<summary-marks available="20" obtained="13.5" />')
        )

        expect {
          described_class.new(xml).import!
        }.to raise_error(TestResultImporter::InvalidDocumentError, /Invalid integer value/)
      end

      it "accepts large but valid integer marks" do
        xml = build_xml(
          single_result_xml("summary-marks" => '<summary-marks available="999999" obtained="500000" />')
        )

        expect { described_class.new(xml).import! }.to change(TestResult, :count).by(1)

        result = TestResult.last
        expect(result.marks_available).to eq(999999)
        expect(result.marks_obtained).to eq(500000)
      end

      it "rejects negative marks-available" do
        xml = build_xml(
          single_result_xml("summary-marks" => '<summary-marks available="-5" obtained="0" />')
        )

        expect {
          described_class.new(xml).import!
        }.to raise_error(TestResultImporter::InvalidDocumentError)
      end

      it "rejects negative marks-obtained" do
        xml = build_xml(
          single_result_xml("summary-marks" => '<summary-marks available="20" obtained="-3" />')
        )

        expect {
          described_class.new(xml).import!
        }.to raise_error(TestResultImporter::InvalidDocumentError)
      end
    end

    context "with marks_obtained exceeding marks_available" do
      it "rejects the document" do
        xml = build_xml(
          single_result_xml("summary-marks" => '<summary-marks available="10" obtained="15" />')
        )

        expect {
          described_class.new(xml).import!
        }.to raise_error(TestResultImporter::InvalidDocumentError, /exceed/)
      end
    end

    context "with scanned-on parsing" do
      it "stores scanned_on as a parsed datetime" do
        xml = build_xml(single_result_xml)
        described_class.new(xml).import!

        result = TestResult.last
        expect(result.scanned_on).to be_a(Time)
        expect(result.scanned_on.year).to eq(2017)
        expect(result.scanned_on.month).to eq(12)
        expect(result.scanned_on.day).to eq(4)
      end

      it "rejects missing scanned-on attribute" do
        xml = build_xml(<<~XML)
          <mcq-test-result>
            <first-name>Jane</first-name>
            <last-name>Austen</last-name>
            <student-number>521585128</student-number>
            <test-id>1234</test-id>
            <summary-marks available="20" obtained="13" />
          </mcq-test-result>
        XML

        expect {
          described_class.new(xml).import!
        }.to raise_error(TestResultImporter::InvalidDocumentError, /scanned-on/)
      end

      it "rejects invalid scanned-on datetime" do
        xml = build_xml(<<~XML)
          <mcq-test-result scanned-on="not-a-date">
            <first-name>Jane</first-name>
            <last-name>Austen</last-name>
            <student-number>521585128</student-number>
            <test-id>1234</test-id>
            <summary-marks available="20" obtained="13" />
          </mcq-test-result>
        XML

        expect {
          described_class.new(xml).import!
        }.to raise_error(TestResultImporter::InvalidDocumentError, /Invalid datetime value/)
      end
    end
  end
end
