class TestResultImporter
  class InvalidDocumentError < StandardError; end
  class MalformedXmlError < StandardError; end

  XML_ROOT_NAME = "mcq-test-results".freeze

  def initialize(xml_body)
    @xml_body = xml_body
  end

  def import!
    doc = parse_xml
    results = extract_results(doc)
    validate_all!(results)
    deduped = deduplicate(results)
    TestResult.upsert_results(deduped)
    deduped.size
  end

  private

  attr_reader :xml_body

  def parse_xml
    doc = Nokogiri::XML(xml_body) { |config| config.strict }

    if doc.root.nil? || doc.root.name != XML_ROOT_NAME
      raise MalformedXmlError, "Root element must be <#{XML_ROOT_NAME}>"
    end

    doc
  rescue Nokogiri::XML::SyntaxError => e
    raise MalformedXmlError, "Malformed XML: #{e.message}"
  end

  def extract_results(doc)
    doc.xpath("//mcq-test-result").map do |node|
      summary = node.at_xpath("summary-marks")

      {
        student_number: text_content(node, "student-number"),
        test_id: text_content(node, "test-id"),
        first_name: text_content(node, "first-name"),
        last_name: text_content(node, "last-name"),
        marks_available: parse_integer(summary&.attr("available")),
        marks_obtained: parse_integer(summary&.attr("obtained")),
        scanned_on: parse_datetime(node.attr("scanned-on"))
      }
    end
  end

  def text_content(node, element_name)
    node.at_xpath(element_name)&.text&.strip.presence
  end

  def parse_integer(value)
    return nil if value.nil?

    Integer(value)
  rescue ArgumentError
    raise InvalidDocumentError, "Invalid integer value: #{value.inspect}"
  end

  def parse_datetime(value)
    return nil if value.blank?

    Time.parse(value)
  rescue ArgumentError
    raise InvalidDocumentError, "Invalid datetime value: #{value.inspect}"
  end

  def validate_all!(results)
    if results.empty?
      return
    end

    results.each_with_index do |result, index|
      errors = validate_result(result)
      unless errors.empty?
        raise InvalidDocumentError,
          "Result ##{index + 1} is invalid: #{errors.join(', ')}"
      end
    end
  end

  def validate_result(result)
    errors = []

    errors << "missing student-number" if result[:student_number].blank?
    errors << "missing test-id" if result[:test_id].blank?
    errors << "missing first-name" if result[:first_name].blank?
    errors << "missing last-name" if result[:last_name].blank?
    errors << "missing summary-marks" if result[:marks_available].nil? || result[:marks_available] <= 0
    errors << "missing scanned-on" if result[:scanned_on].nil?
    errors << "marks-obtained is required" if result[:marks_obtained].nil?
    errors << "marks-obtained must be non-negative" if result[:marks_obtained]&.negative?
    errors << "marks-obtained cannot exceed marks-available" if result[:marks_obtained] && result[:marks_available] && result[:marks_obtained] > result[:marks_available]

    errors
  end

  def deduplicate(results)
    results.each_with_object({}) do |r, hash|
      key = [r[:test_id], r[:student_number]]
      existing = hash[key]
      if existing.nil?
        hash[key] = r
      else
        hash[key] = existing.merge(
          marks_obtained: [existing[:marks_obtained], r[:marks_obtained]].max,
          marks_available: [existing[:marks_available], r[:marks_available]].max
        )
      end
    end.values
  end
end