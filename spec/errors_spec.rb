# frozen_string_literal: true

require "spec_helper"

RSpec.describe "error mapping" do
  let(:client) { build_client }

  it "exposes field errors on a validation error" do
    server.stub(:post, "/v1/email", status: 422, body: {
      error: {type: "validation_error", message: "Invalid request.", errors: {to: ["must not be empty"]}}
    })

    expect { client.email.send(from: "a@b.com", to: [], text: "x") }
      .to raise_error(Anypost::ValidationError) { |e|
        expect(e.type).to eq("validation_error")
        expect(e.status).to eq(422)
        expect(e.errors).to eq({"to" => ["must not be empty"]})
        expect(e.message).to eq("Invalid request.")
      }
  end

  {
    401 => ["authentication_error", Anypost::AuthenticationError],
    403 => ["permission_error", Anypost::PermissionError],
    404 => ["not_found", Anypost::NotFoundError],
    409 => ["idempotency_concurrent", Anypost::ConflictError],
    422 => ["idempotency_mismatch", Anypost::IdempotencyMismatchError],
    500 => ["internal_error", Anypost::APIError]
  }.each do |status, (type, klass)|
    it "maps #{type} to #{klass}" do
      server.stub(:get, "/v1/whoami", status: status, body: {error: {type: type, message: "nope"}})
      expect { client.whoami }.to raise_error(klass) { |e| expect(e.type).to eq(type) }
    end
  end

  it "parses Retry-After on a rate-limit error" do
    server.stub(:get, "/v1/whoami", status: 429,
      headers: {"Content-Type" => "application/json", "Retry-After" => "7"},
      body: {error: {type: "rate_limit_exceeded", message: "slow down"}})

    expect { build_client("ap_test", max_retries: 0).whoami }
      .to raise_error(Anypost::RateLimitError) { |e| expect(e.retry_after).to eq(7.0) }
  end

  it "handles the flat 413 envelope" do
    server.stub(:post, "/v1/email", status: 413, body: {error: "payload_too_large"})

    expect { client.email.send(from: "a@b.com", to: ["c@d.com"], text: "x") }
      .to raise_error(Anypost::PayloadTooLargeError) { |e|
        expect(e.type).to eq("payload_too_large")
        expect(e.status).to eq(413)
      }
  end

  it "captures the request id header" do
    server.stub(:get, "/v1/domains/dom_1", status: 404,
      headers: {"Content-Type" => "application/json", "Anypost-Request-Id" => "req_123"},
      body: {error: {type: "not_found", message: "gone"}})

    expect { client.domains.get("dom_1") }
      .to raise_error(Anypost::NotFoundError) { |e| expect(e.request_id).to eq("req_123") }
  end

  it "falls back to the status when the body has no type" do
    server.stub(:get, "/v1/whoami", status: 403, body: {})
    expect { client.whoami }.to raise_error(Anypost::PermissionError)
  end
end
