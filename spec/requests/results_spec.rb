require "rails_helper"

RSpec.describe "GET /results/:test_id/aggregate", type: :request do
  describe "with no results" do
    it "returns 404" do
      get "/results/9999/aggregate"

      expect(response).to have_http_status(:not_found)
    end

    it "returns an error message" do
      get "/results/9999/aggregate"
      body = JSON.parse(response.body)

      expect(body["error"]).to eq("Test not found")
    end
  end

  describe "with a single result" do
    let(:test_id) { "1234" }
    before do
      create(:test_result, test_id: test_id, marks_obtained: 13, marks_available: 20)
    end

    it "returns 200" do
      get "/results/#{test_id}/aggregate"
      expect(response).to have_http_status(:ok)
    end

    it "returns correct aggregate as percentages" do
      get "/results/#{test_id}/aggregate"
      body = JSON.parse(response.body)

      expect(body["mean"]).to eq(65.0)
      expect(body["stddev"]).to eq(0.0)
      expect(body["min"]).to eq(65.0)
      expect(body["max"]).to eq(65.0)
      expect(body["p25"]).to eq(65.0)
      expect(body["p50"]).to eq(65.0)
      expect(body["p75"]).to eq(65.0)
      expect(body["count"]).to eq(1)
    end
  end

  describe "with multiple results" do
    let(:test_id) { "1234" }
    before do
      [5, 10, 13, 17, 20].each_with_index do |obtained, i|
        create(:test_result,
          student_number: "STU#{i}",
          test_id: test_id,
          marks_obtained: obtained,
          marks_available: 20
        )
      end
    end

    it "returns correct count" do
      get "/results/#{test_id}/aggregate"
      body = JSON.parse(response.body)

      expect(body["count"]).to eq(5)
    end

    it "returns correct mean" do
      get "/results/#{test_id}/aggregate"
      body = JSON.parse(response.body)

      expect(body["mean"]).to eq(65.0)
    end

    it "returns correct min and max" do
      get "/results/#{test_id}/aggregate"
      body = JSON.parse(response.body)

      expect(body["min"]).to eq(25.0)
      expect(body["max"]).to eq(100.0)
    end

    it "returns correct percentiles" do
      get "/results/#{test_id}/aggregate"
      body = JSON.parse(response.body)

      expect(body["p25"]).to eq(50.0)
      expect(body["p50"]).to eq(65.0)
      expect(body["p75"]).to eq(85.0)
    end
  end

  describe "scoping by test_id" do
    before do
      create(:test_result, student_number: "STU1", test_id: "1234", marks_obtained: 10, marks_available: 20)
      create(:test_result, student_number: "STU2", test_id: "5678", marks_obtained: 18, marks_available: 20)
    end

    it "only includes results for the requested test" do
      get "/results/1234/aggregate"
      body = JSON.parse(response.body)

      expect(body["count"]).to eq(1)
      expect(body["mean"]).to eq(50.0)
    end
  end
end
