# Markr — Exam Result Ingestion Service

A data ingestion microservice that accepts multiple-choice exam results from legacy scanning machines via XML and provides aggregate statistics via a JSON API.

## How to Build and Run

### With Docker Compose

```bash
docker compose up --build
```

This starts PostgreSQL and the Rails server on **port 4567**.

### Local Development

Requires Ruby 4.0.1 and PostgreSQL running locally.

```bash
bundle install
rails db:create db:migrate
rails server -p 4567
```

### Running Tests

```bash
bundle install
rails db:create db:migrate RAILS_ENV=test
bundle exec rspec
```

## API Endpoints

### POST /import

Accepts XML documents from the grading machines.

```bash
curl -X POST -H 'Content-Type: text/xml+markr' http://localhost:4567/import -d @- <<XML
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
```

**Responses:**
- `200 OK` — document imported successfully
- `400 Bad Request` — malformed XML or wrong root element
- `415 Unsupported Media Type` — wrong Content-Type (must be `text/xml+markr`)
- `422 Unprocessable Entity` — missing required fields; entire document rejected

### GET /results/:test_id/aggregate

Returns aggregate statistics for a test. All scores are expressed as percentages (0-100).

```bash
curl http://localhost:4567/results/1234/aggregate
```

```json
{"mean":65.0,"stddev":0.0,"min":65.0,"max":65.0,"p25":65.0,"p50":65.0,"p75":65.0,"count":1}
```

**Responses:**
- `200 OK` — aggregate statistics returned
- `404 Not Found` — no results exist for the given test ID

## Architecture Decision

### Data Model

A single `test_results` table with a composite unique index on `(test_id, student_number)`. 
This enforces one record per student per test at the database level.

### Duplicate Handling

Duplicates are handled via PostgreSQL `UPSERT` with `GREATEST`:
- On conflict, `marks_obtained` and `marks_available` are updated to the **higher** of the existing and incoming values.
- Since PostgreSQL cannot handle duplicate keys in a single `INSERT ... ON CONFLICT`, duplicates within the same XML document are deduplicated in Ruby before the upsert.

### Data Validation

1. Parse the entire XML document.
2. Validate ALL results before store in the database.
3. If any result is invalid, reject the entire document with a 422 — zero records are persisted.

### Aggregate Computation

Statistics are computed in Ruby by pulling all scores for a test and calculating in-memory. 
This is simple, testable, and sufficient for the current dataset sizes.