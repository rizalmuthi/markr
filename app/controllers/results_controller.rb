class ResultsController < ApplicationController
  def aggregate
    result = TestResult.aggregate_for(params[:test_id])

    if result.nil?
      render json: { error: "Test not found" }, status: :not_found
    else
      render json: result
    end
  end
end
