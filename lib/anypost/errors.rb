# frozen_string_literal: true

require "time"

module Anypost
  # Base class for every error raised by the SDK.
  #
  # Branch on {#type} (the stable, machine-readable code) rather than on the
  # HTTP status or the message text.
  class Error < StandardError
    # @return [String] stable, machine-readable error type
    attr_reader :type
    # @return [Integer, nil] HTTP status, or nil when no response was received
    attr_reader :status
    # @return [String, nil] request id from the response, when present
    attr_reader :request_id
    # @return [Object] the parsed response body, or the underlying cause
    attr_reader :raw

    def initialize(message, type:, status: nil, request_id: nil, raw: nil)
      super(message)
      @type = type
      @status = status
      @request_id = request_id
      @raw = raw
    end
  end

  # 400/422 — the request body or query failed validation.
  class ValidationError < Error
    # @return [Hash{String => Array<String>}] field path -> list of problems
    attr_reader :errors

    def initialize(message, errors: {}, **kwargs)
      super(message, **kwargs)
      @errors = errors || {}
    end
  end

  # 401 — the API key is missing or invalid.
  class AuthenticationError < Error; end

  # 403 — the key may not perform this action.
  class PermissionError < Error; end

  # 404 — no such resource for this team.
  class NotFoundError < Error; end

  # 409 — conflict, idempotency_concurrent, or webhook_rotation_in_progress.
  class ConflictError < Error; end

  # 422 idempotency_mismatch — a key was reused with a different body.
  class IdempotencyMismatchError < Error; end

  # 429 — a rate limit was exceeded.
  class RateLimitError < Error
    # @return [Float, nil] parsed Retry-After, in seconds, when the server sent one
    attr_reader :retry_after

    def initialize(message, retry_after: nil, **kwargs)
      super(message, **kwargs)
      @retry_after = retry_after
    end
  end

  # 413 — the request body exceeded the 5 MB gateway limit.
  class PayloadTooLargeError < Error; end

  # A server error (5xx), including internal_error and provisioning_error.
  class APIError < Error; end

  # No HTTP response was received (network failure, timeout, or abort).
  class APIConnectionError < Error
    def initialize(message, cause: nil)
      super(message, type: "connection_error", raw: cause)
    end
  end

  # Maps an HTTP response into the right {Error} subclass. Keys primarily on the
  # canonical `error.type`, falling back to the HTTP status.
  #
  # @api private
  module Errors
    REQUEST_ID_HEADERS = ["anypost-request-id", "x-anypost-request-id", "x-request-id"].freeze

    module_function

    def from_response(status, body, headers)
      request_id = read_request_id(headers)
      envelope = body.is_a?(Hash) ? body : {}
      error = envelope["error"]

      errors = {}
      case error
      when Hash
        # Canonical envelope: { error: { type, message, errors? } }.
        type = error["type"] || type_from_status(status)
        message = error["message"] || default_message(status)
        errors = error["errors"] if error["errors"].is_a?(Hash)
      when String
        # Flat envelope: { error: "<code>", message? }.
        type = error
        message = envelope["message"] || error.tr("_", " ")
      else
        type = type_from_status(status)
        message = default_message(status)
      end

      build(status, type, message, errors || {}, request_id, body, headers)
    end

    # Parse a Retry-After header (delta-seconds or HTTP-date) into seconds.
    def retry_after_seconds(headers)
      value = header(headers, "retry-after")
      return nil if value.nil? || value.empty?
      return [value.to_f, 0.0].max if /\A\s*\d+(\.\d+)?\s*\z/.match?(value)

      begin
        target = Time.httpdate(value)
      rescue ArgumentError
        return nil
      end
      [target.to_f - Time.now.to_f, 0.0].max
    end

    def build(status, type, message, errors, request_id, raw, headers)
      common = {status: status, request_id: request_id, raw: raw}
      case type
      when "validation_error"
        ValidationError.new(message, errors: errors, type: type, **common)
      when "authentication_error"
        AuthenticationError.new(message, type: type, **common)
      when "permission_error"
        PermissionError.new(message, type: type, **common)
      when "not_found"
        NotFoundError.new(message, type: type, **common)
      when "conflict", "idempotency_concurrent", "webhook_rotation_in_progress"
        ConflictError.new(message, type: type, **common)
      when "idempotency_mismatch"
        IdempotencyMismatchError.new(message, type: type, **common)
      when "rate_limit_exceeded"
        RateLimitError.new(message, retry_after: retry_after_seconds(headers), type: type, **common)
      when "payload_too_large"
        PayloadTooLargeError.new(message, type: type, **common)
      when "provisioning_error", "internal_error"
        APIError.new(message, type: type, **common)
      else
        by_status(status, type, message, errors, headers, common)
      end
    end

    def by_status(status, type, message, errors, headers, common)
      case status
      when 401 then AuthenticationError.new(message, type: type, **common)
      when 403 then PermissionError.new(message, type: type, **common)
      when 404 then NotFoundError.new(message, type: type, **common)
      when 409 then ConflictError.new(message, type: type, **common)
      when 413 then PayloadTooLargeError.new(message, type: type, **common)
      when 429 then RateLimitError.new(message, retry_after: retry_after_seconds(headers), type: type, **common)
      when 400, 422 then ValidationError.new(message, errors: errors, type: type, **common)
      else
        (status >= 500) ? APIError.new(message, type: type, **common) : Error.new(message, type: type, **common)
      end
    end

    def type_from_status(status)
      case status
      when 400, 422 then "validation_error"
      when 401 then "authentication_error"
      when 403 then "permission_error"
      when 404 then "not_found"
      when 409 then "conflict"
      when 413 then "payload_too_large"
      when 429 then "rate_limit_exceeded"
      else
        (status >= 500) ? "internal_error" : "api_error"
      end
    end

    def default_message(status)
      "Anypost request failed with status #{status}."
    end

    def read_request_id(headers)
      REQUEST_ID_HEADERS.each do |name|
        value = header(headers, name)
        return value if value && !value.empty?
      end
      nil
    end

    # Case-insensitive single-value header lookup over a Hash or Faraday headers.
    def header(headers, name)
      return nil if headers.nil?

      name = name.downcase
      headers.each do |key, value|
        return value if key.to_s.downcase == name
      end
      nil
    end
  end
end
