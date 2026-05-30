# frozen_string_literal: true

require "spec_helper"

RSpec.describe Anypost::Client do
  it "raises without an API key" do
    original = ENV.delete("ANYPOST_API_KEY")
    expect { described_class.new(nil, connection: server.connection) }
      .to raise_error(ArgumentError, /API key is required/)
  ensure
    ENV["ANYPOST_API_KEY"] = original if original
  end

  it "falls back to the ANYPOST_API_KEY environment variable" do
    original = ENV["ANYPOST_API_KEY"]
    ENV["ANYPOST_API_KEY"] = "ap_from_env"
    server.stub(:get, "/v1/whoami", body: {team: nil})

    client = described_class.new(nil, connection: server.connection, sleeper: ->(_) {}, jitter: -> { 1.0 })
    client.whoami

    expect(server.last_request.header("Authorization")).to eq("Bearer ap_from_env")
  ensure
    ENV["ANYPOST_API_KEY"] = original
  end

  it "sends the expected default headers" do
    server.stub(:post, "/v1/email", status: 202, body: {id: "email_1", created_at: "now"})
    build_client.email.send(from: "a@b.com", to: ["c@d.com"], subject: "Hi", text: "Yo")

    request = server.last_request
    expect(request.header("Authorization")).to eq("Bearer ap_test")
    expect(request.header("Accept")).to eq("application/json")
    expect(request.header("Content-Type")).to eq("application/json")
    expect(request.header("User-Agent")).to start_with("anypost-ruby/#{Anypost::VERSION}")
  end

  it "merges custom default headers" do
    server.stub(:get, "/v1/whoami", body: {team: nil})
    build_client("ap_test", default_headers: {"X-Trace" => "abc123"}).whoami

    expect(server.last_request.header("X-Trace")).to eq("abc123")
  end

  it "keeps the /v1 base path on every request" do
    server.stub(:get, "/v1/whoami", body: {team: nil})
    build_client.whoami

    expect(server.last_request.path).to eq("/v1/whoami")
  end
end
