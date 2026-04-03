class ImportsController < ApplicationController
  ACCEPTED_CONTENT_TYPE = "text/xml+markr".freeze
  MAX_BODY_SIZE = 10.megabytes

  def create
    unless request.content_type == ACCEPTED_CONTENT_TYPE
      return render json: { error: "Content-Type must be #{ACCEPTED_CONTENT_TYPE}" }, status: :unsupported_media_type
    end

    body = request.body.read
    if body.bytesize > MAX_BODY_SIZE
      return render json: { error: "Request body too large (max #{MAX_BODY_SIZE / 1.megabyte}MB)" }, status: :content_too_large
    end

    importer = TestResultImporter.new(body)
    count = importer.import!

    render json: { imported: count }, status: :ok
  rescue TestResultImporter::MalformedXmlError => e
    render json: { error: e.message }, status: :bad_request
  rescue TestResultImporter::InvalidDocumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
