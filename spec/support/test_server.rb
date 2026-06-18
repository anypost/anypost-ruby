# frozen_string_literal: true

# A thin wrapper over Faraday's test adapter: enqueue responses (or errors) per
# method+path and capture each request for assertions. Multiple stubs for the
# same path are consumed in order, which is what the retry specs rely on.
class TestServer
  Request = Struct.new(:method, :path, :query, :headers, :body) do
    def json_body
      JSON.parse(body)
    end

    def header(name)
      headers[name] || headers[name.downcase] || headers.to_h.find { |k, _| k.to_s.downcase == name.downcase }&.last
    end
  end

  attr_reader :requests

  def initialize(base_url: "https://api.anypost.com/v1")
    @base_url = base_url
    @stubs = Faraday::Adapter::Test::Stubs.new
    @requests = []
  end

  def connection
    @connection ||= Faraday.new(url: "#{@base_url}/") do |faraday|
      faraday.adapter(:test, @stubs)
    end
  end

  def stub(method, path, status: 200, headers: {"Content-Type" => "application/json"}, body: {})
    payload = body.is_a?(String) ? body : JSON.generate(body)
    @stubs.public_send(method, path) do |env|
      record(env)
      [status, headers, payload]
    end
  end

  def stub_error(method, path, error)
    @stubs.public_send(method, path) do |env|
      record(env)
      raise error
    end
  end

  def last_request
    @requests.last
  end

  private

  def record(env)
    @requests << Request.new(
      method: env.method,
      path: env.url.path,
      query: Faraday::Utils.parse_query(env.url.query || ""),
      headers: env.request_headers,
      body: env.request_body
    )
  end
end

module TestServerHelper
  def server
    @server ||= TestServer.new
  end

  # Build a client wired to the test server, with sleep disabled and a
  # deterministic full-jitter factor.
  def build_client(api_key = "ap_test", **options)
    Anypost::Client.new(
      api_key,
      connection: server.connection,
      sleeper: ->(_seconds) {},
      jitter: -> { 1.0 },
      **options
    )
  end
end
