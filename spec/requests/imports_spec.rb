require "rails_helper"

RSpec.describe "POST /import", type: :request do
  let(:valid_xml) do
    <<~XML
      <mcq-test-results>
        <mcq-test-result scanned-on="2017-12-04T12:12:10+11:00">
          <first-name>Jane</first-name>
          <last-name>Austen</last-name>
          <student-number>521585128</student-number>
          <test-id>1234</test-id>
          <summary-marks available="20" obtained="13" />
        </mcq-test-result>
      </mcq-test-results>
    XML
  end

  let(:headers) { { "CONTENT_TYPE" => "text/xml+markr" } }

  describe "content type validation" do
    it "accepts text/xml+markr content type" do
      post "/import", params: valid_xml, headers: headers

      expect(response).to have_http_status(:ok)
    end

    it "rejects wrong content type with 415" do
      post "/import", params: valid_xml, headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:unsupported_media_type)
    end

    it "rejects missing content type with 415" do
      post "/import", params: valid_xml

      expect(response).to have_http_status(:unsupported_media_type)
    end
  end

  describe "successful import" do
    it "persists test results to the database" do
      expect {
        post "/import", params: valid_xml, headers: headers
      }.to change(TestResult, :count).by(1)
    end

    it "returns the import count" do
      post "/import", params: valid_xml, headers: headers
      
      body = JSON.parse(response.body)

      expect(body["imported"]).to eq(1)
    end

    it "stores correct data" do
      post "/import", params: valid_xml, headers: headers

      result = TestResult.last

      expect(result.student_number).to eq("521585128")
      expect(result.test_id).to eq("1234")
      expect(result.first_name).to eq("Jane")
      expect(result.last_name).to eq("Austen")
      expect(result.marks_available).to eq(20)
      expect(result.marks_obtained).to eq(13)
    end
  end

  describe "duplicate handling" do
    it "keeps the highest score across multiple requests" do
      low_score_xml = valid_xml.sub('obtained="13"', 'obtained="10"')
      high_score_xml = valid_xml.sub('obtained="13"', 'obtained="18"')

      post "/import", params: low_score_xml, headers: headers
      post "/import", params: high_score_xml, headers: headers

      expect(TestResult.count).to eq(1)
      expect(TestResult.last.marks_obtained).to eq(18)
    end

    it "does not downgrade score on re-import" do
      high_score_xml = valid_xml.sub('obtained="13"', 'obtained="18"')
      low_score_xml = valid_xml.sub('obtained="13"', 'obtained="10"')

      post "/import", params: high_score_xml, headers: headers
      post "/import", params: low_score_xml, headers: headers

      expect(TestResult.last.marks_obtained).to eq(18)
    end
  end

  describe "body size limit" do
    it "rejects request bodies exceeding the size limit" do
      oversized_body = "<mcq-test-results>" + ("x" * (11 * 1024 * 1024)) + "</mcq-test-results>"

      post "/import", params: oversized_body, headers: headers

      expect(response).to have_http_status(:content_too_large)
      body = JSON.parse(response.body)
      expect(body["error"]).to match(/too large/)
    end

    it "accepts request bodies within the size limit" do
      post "/import", params: valid_xml, headers: headers

      expect(response).to have_http_status(:ok)
    end
  end

  describe "invalid marks values" do
    it "returns 422 for non-numeric marks-available" do
      xml = valid_xml.sub('available="20"', 'available="abc"')
      post "/import", params: xml, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["error"]).to match(/Invalid integer/)
    end

    it "returns 422 for non-numeric marks-obtained" do
      xml = valid_xml.sub('obtained="13"', 'obtained="xyz"')
      post "/import", params: xml, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["error"]).to match(/Invalid integer/)
    end
  end

  describe "scanned-on datetime handling" do
    it "returns 422 for invalid scanned-on datetime" do
      xml = valid_xml.sub('scanned-on="2017-12-04T12:12:10+11:00"', 'scanned-on="not-a-date"')
      post "/import", params: xml, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["error"]).to match(/Invalid datetime/)
    end
  end

  describe "error handling" do
    it "returns 400 for malformed XML" do
      post "/import", params: "<bad xml<>", headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns 400 for wrong root element" do
      post "/import", params: "<wrong-root/>", headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns 422 for missing required fields" do
      invalid_xml = valid_xml.gsub(/<student-number>.*<\/student-number>/, "")
      post "/import", params: invalid_xml, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not persist any records when document has invalid results" do
      two_results_xml = <<~XML
        <mcq-test-results>
          <mcq-test-result scanned-on="2017-12-04T12:12:10+11:00">
            <first-name>Jane</first-name>
            <last-name>Austen</last-name>
            <student-number>521585128</student-number>
            <test-id>1234</test-id>
            <summary-marks available="20" obtained="13" />
          </mcq-test-result>
          <mcq-test-result scanned-on="2017-12-04T12:12:10+11:00">
            <first-name>Invalid</first-name>
            <last-name>Student</last-name>
            <test-id>1234</test-id>
            <summary-marks available="20" obtained="13" />
          </mcq-test-result>
        </mcq-test-results>
      XML

      expect {
        post "/import", params: two_results_xml, headers: headers
      }.not_to change(TestResult, :count)
    end
  end

  describe "edge case handling of the xml data" do
    it "ignores <answer> elements and uses summary-marks" do
      xml = <<~XML
        <mcq-test-results>
          <mcq-test-result scanned-on="2017-12-04T12:12:10+11:00">
            <first-name>Jane</first-name>
            <last-name>Doe</last-name>
            <student-number>STU001</student-number>
            <test-id>1234</test-id>
            <answer question="1" marks-available="1" marks-awarded="1">A</answer>
            <answer question="2" marks-available="1" marks-awarded="0">B</answer>
            <summary-marks available="20" obtained="13" />
          </mcq-test-result>
        </mcq-test-results>
      XML

      post "/import", params: xml, headers: headers
      expect(response).to have_http_status(:ok)

      result = TestResult.last
      expect(result.marks_obtained).to eq(13)
      expect(result.marks_available).to eq(20)
    end

    it "ignores extra/unknown XML elements" do
      xml = <<~XML
        <mcq-test-results>
          <mcq-test-result scanned-on="2017-12-04T12:12:10+11:00">
            <first-name>Jane</first-name>
            <last-name>Doe</last-name>
            <student-number>STU001</student-number>
            <test-id>1234</test-id>
            <some-extra-field>whatever</some-extra-field>
            <reporting-data>gunk</reporting-data>
            <summary-marks available="20" obtained="13" />
          </mcq-test-result>
        </mcq-test-results>
      XML

      post "/import", params: xml, headers: headers
      expect(response).to have_http_status(:ok)
      expect(TestResult.count).to eq(1)
    end
  end
end
