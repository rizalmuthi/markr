require "rails_helper"

RSpec.describe "Sample data end-to-end", type: :request do
  let(:sample_xml) { File.read(Rails.root.join("spec/fixtures/sample_results.xml")) }
  let(:headers) { { "CONTENT_TYPE" => "text/xml+markr" } }

  before do
    post "/import", params: sample_xml, headers: headers
  end

  it "imports successfully" do
    expect(response).to have_http_status(:ok)
  end

  it "deduplicates to 81 unique students" do
    expect(TestResult.count).to eq(81)
  end

  it "all results belong to test 9863" do
    expect(TestResult.distinct.pluck(:test_id)).to eq(["9863"])
  end

  describe "GET /results/9863/aggregate" do
    before do
      get "/results/9863/aggregate"
    end

    it "returns 200" do
      expect(response).to have_http_status(:ok)
    end

    it "returns correct count" do
      body = JSON.parse(response.body)
      expect(body["count"]).to eq(81)
    end

    it "returns correct mean" do
      body = JSON.parse(response.body)
      expect(body["mean"]).to be_within(0.01).of(50.80)
    end

    it "returns correct min and max" do
      body = JSON.parse(response.body)
      expect(body["min"]).to eq(30.0)
      expect(body["max"]).to eq(75.0)
    end

    it "returns correct percentiles" do
      body = JSON.parse(response.body)
      expect(body["p25"]).to eq(45.0)
      expect(body["p50"]).to eq(50.0)
      expect(body["p75"]).to be_within(0.01).of(55.0)
    end

    it "returns correct stddev" do
      body = JSON.parse(response.body)
      expect(body["stddev"]).to be_within(0.01).of(9.92)
    end
  end
end
