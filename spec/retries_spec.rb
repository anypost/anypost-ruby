# frozen_string_literal: true

require "spec_helper"

RSpec.describe "retries" do
  let(:client) { build_client }

  it "retries on 429 then succeeds" do
    server.stub(:post, "/v1/email", status: 429, body: {error: {type: "rate_limit_exceeded"}})
    server.stub(:post, "/v1/email", status: 202, body: {id: "email_ok", created_at: "now"})

    email = client.email.send(from: "a@b.com", to: ["c@d.com"], text: "x")

    expect(email.id).to eq("email_ok")
    expect(server.requests.length).to eq(2)
  end

  it "reuses one idempotency key across send retries" do
    server.stub(:post, "/v1/email", status: 503, body: {error: {type: "provisioning_error"}})
    server.stub(:post, "/v1/email", status: 202, body: {id: "email_ok", created_at: "now"})

    client.email.send(from: "a@b.com", to: ["c@d.com"], text: "x")

    first = server.requests[0].header("Idempotency-Key")
    second = server.requests[1].header("Idempotency-Key")
    expect(first).not_to be_nil
    expect(second).to eq(first)
  end

  it "retries a network error then gives up" do
    3.times { server.stub_error(:get, "/v1/whoami", Faraday::ConnectionFailed.new("boom")) }

    expect { client.whoami }.to raise_error(Anypost::APIConnectionError)
    expect(server.requests.length).to eq(3)
  end

  it "recovers from a transient network error" do
    server.stub_error(:get, "/v1/whoami", Faraday::ConnectionFailed.new("boom"))
    server.stub(:get, "/v1/whoami", body: {team: nil})

    result = client.whoami

    expect(result.team).to be_nil
    expect(server.requests.length).to eq(2)
  end

  it "does not retry on a 4xx" do
    server.stub(:post, "/v1/email", status: 422, body: {error: {type: "validation_error", message: "bad"}})

    expect { client.email.send(from: "a@b.com", to: [], text: "x") }.to raise_error(Anypost::ValidationError)
    expect(server.requests.length).to eq(1)
  end

  it "respects max_retries: 0" do
    server.stub(:get, "/v1/whoami", status: 429, body: {error: {type: "rate_limit_exceeded"}})

    expect { build_client("ap_test", max_retries: 0).whoami }.to raise_error(Anypost::RateLimitError)
    expect(server.requests.length).to eq(1)
  end
end
