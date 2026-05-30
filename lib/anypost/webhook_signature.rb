# frozen_string_literal: true

require "openssl"
require "json"

module Anypost
  # Raised when a webhook delivery's signature cannot be verified.
  class WebhookVerificationError < StandardError
    # The machine-readable reason. Branch on this rather than the message.
    #
    # One of: :malformed_header, :no_timestamp, :no_signatures,
    # :timestamp_out_of_tolerance, :no_match.
    #
    # @return [Symbol]
    attr_reader :reason

    def initialize(message, reason)
      super(message)
      @reason = reason
    end
  end

  # Verify the signature on an Anypost webhook delivery.
  module WebhookSignature
    DEFAULT_TOLERANCE_SECONDS = 300

    module_function

    # Verify an Anypost webhook signature.
    #
    # Pass the **raw** request body (the exact bytes received, before JSON
    # parsing), the `Anypost-Signature` header value, and the webhook's signing
    # secret. Returns nil on success; raises {WebhookVerificationError} otherwise.
    #
    # The header may carry more than one `v1=` component during a secret
    # rotation; a match on any one passes, so deliveries keep verifying across a
    # rotation. Set `tolerance_seconds:` to 0 to disable the freshness check.
    def verify(payload, signature_header, secret, tolerance_seconds: DEFAULT_TOLERANCE_SECONDS, now: nil)
      timestamp, signatures = parse_header(signature_header)

      if tolerance_seconds.positive?
        current = now || Time.now.to_i
        if current - timestamp > tolerance_seconds
          raise WebhookVerificationError.new(
            "Timestamp #{timestamp} is older than the #{tolerance_seconds}s tolerance.",
            :timestamp_out_of_tolerance
          )
        end
      end

      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")

      # Constant-time over every candidate: accumulate without early exit.
      matched = false
      signatures.each { |candidate| matched = true if secure_compare(candidate, expected) }

      unless matched
        raise WebhookVerificationError.new(
          "No signature in the header matched the computed signature.",
          :no_match
        )
      end

      nil
    end

    # Verify a delivery and return its parsed body as a {Response}.
    #
    # A thin wrapper over {.verify} that parses the JSON only after the signature
    # checks out.
    def unwrap(payload, signature_header, secret, tolerance_seconds: DEFAULT_TOLERANCE_SECONDS, now: nil)
      verify(payload, signature_header, secret, tolerance_seconds: tolerance_seconds, now: now)
      decoded = JSON.parse(payload)
      Response.new(decoded.is_a?(Hash) ? decoded : {})
    end

    def parse_header(header)
      if header.nil? || header.empty?
        raise WebhookVerificationError.new("The Anypost-Signature header is empty.", :malformed_header)
      end

      timestamp = nil
      signatures = []

      header.split(",").each do |part|
        key, separator, value = part.partition("=")
        next if separator.empty?

        key = key.strip
        value = value.strip
        if key == "t"
          timestamp = value.to_i if /\A\d+\z/.match?(value)
        elsif key == "v1"
          signatures << value
        end
      end

      if timestamp.nil?
        raise WebhookVerificationError.new("The Anypost-Signature header has no timestamp (t=).", :no_timestamp)
      end
      if signatures.empty?
        raise WebhookVerificationError.new("The Anypost-Signature header has no v1= signature.", :no_signatures)
      end

      [timestamp, signatures]
    end

    def secure_compare(left, right)
      return false unless left.bytesize == right.bytesize

      OpenSSL.fixed_length_secure_compare(left, right)
    end
  end
end
