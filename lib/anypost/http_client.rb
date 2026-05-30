# frozen_string_literal: true

require "json"
require "securerandom"
require "faraday"

module Anypost
  # Owns a Faraday connection and implements the request loop: header assembly,
  # retries with full-jitter backoff, idempotency keys, and error mapping.
  #
  # @api private
  class HttpClient
    RETRYABLE_STATUS = [429, 502, 503].freeze
    MAX_BACKOFF_SECONDS = 8.0
    BASE_BACKOFF_SECONDS = 0.5

    # @param sleeper [#call] override the sleep between retries (tests)
    # @param jitter [#call] override the [0,1) jitter factor (tests)
    def initialize(api_key:, base_url:, timeout:, max_retries:, default_headers: {},
      connection: nil, sleeper: nil, jitter: nil)
      @api_key = api_key
      @max_retries = max_retries
      @default_headers = default_headers
      @connection = connection || build_connection(base_url, timeout)
      @sleeper = sleeper || ->(seconds) { sleep(seconds) if seconds.positive? }
      @jitter = jitter || -> { rand }
    end

    # Perform a request and return the decoded JSON body.
    def request(method, path, body: nil, query: nil, idempotent: false,
      idempotency_key: nil, max_retries: nil, extra_headers: nil)
      retries = max_retries.nil? ? @max_retries : max_retries
      headers = build_headers(
        has_body: !body.nil?,
        idempotent: idempotent,
        idempotency_key: idempotency_key,
        max_retries: retries,
        extra_headers: extra_headers
      )
      payload = body.nil? ? nil : JSON.generate(body)
      params = clean_query(query)
      relative = path.sub(%r{\A/+}, "")

      attempt = 0
      loop do
        begin
          response = @connection.run_request(method, relative, payload, headers) do |req|
            req.params.update(params) unless params.empty?
          end
        rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
          raise APIConnectionError.new(connection_message(e), cause: e) unless attempt < retries

          @sleeper.call(backoff(attempt, nil))
          attempt += 1
          next
        end

        status = response.status
        return decode(response) if status >= 200 && status < 300

        if RETRYABLE_STATUS.include?(status) && attempt < retries
          @sleeper.call(backoff(attempt, response.headers))
          attempt += 1
          next
        end

        raise Errors.from_response(status, decode(response), response.headers)
      end
    end

    def self.user_agent
      "anypost-ruby/#{Anypost::VERSION} Ruby/#{RUBY_VERSION}"
    end

    private

    def build_connection(base_url, timeout)
      url = base_url.end_with?("/") ? base_url : "#{base_url}/"
      Faraday.new(url: url) do |f|
        f.options.timeout = timeout
        f.adapter Faraday.default_adapter
      end
    end

    def build_headers(has_body:, idempotent:, idempotency_key:, max_retries:, extra_headers:)
      headers = {
        "Authorization" => "Bearer #{@api_key}",
        "Accept" => "application/json",
        "User-Agent" => self.class.user_agent
      }.merge(@default_headers)

      headers["Content-Type"] = "application/json" if has_body

      if idempotent
        if idempotency_key && !idempotency_key.empty?
          headers["Idempotency-Key"] = idempotency_key
        elsif max_retries.positive?
          # Auto-key so built-in retries of a send cannot deliver twice.
          headers["Idempotency-Key"] = SecureRandom.uuid
        end
      end

      headers.merge!(extra_headers) if extra_headers
      headers
    end

    def clean_query(query)
      return {} if query.nil?

      query.each_with_object({}) do |(key, value), out|
        next if value.nil?

        out[key.to_s] = case value
        when true then "true"
        when false then "false"
        else value.to_s
        end
      end
    end

    def backoff(attempt, headers)
      unless headers.nil?
        after = Errors.retry_after_seconds(headers)
        return [after, MAX_BACKOFF_SECONDS].min if after
      end

      ceiling = [BASE_BACKOFF_SECONDS * (2**attempt), MAX_BACKOFF_SECONDS].min
      @jitter.call * ceiling # full jitter
    end

    def decode(response)
      return nil if response.status == 204

      body = response.body
      return nil if body.nil? || (body.respond_to?(:empty?) && body.empty?)
      return body unless body.is_a?(String)

      begin
        JSON.parse(body)
      rescue JSON::ParserError
        body
      end
    end

    def connection_message(error)
      "Could not reach Anypost: #{error.message}"
    end
  end
end
