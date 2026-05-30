# frozen_string_literal: true

module Anypost
  module Resources
    # Operations on the `/email` endpoints.
    #
    # Attachment `content` is the raw file bytes (e.g. from `File.binread`); the
    # SDK base64-encodes it for transport. Do not pre-encode it.
    class Email < Base
      # Send a single message.
      #
      # All addresses in `to`/`cc`/`bcc` share one envelope. Returns the queued
      # message id; raises an {Anypost::Error} subclass on failure.
      def send(email, idempotency_key = nil)
        request_object(:post, "/email",
          body: encode_attachments(email), idempotent: true, idempotency_key: idempotency_key)
      end

      # Send 1-100 independent messages in one request.
      #
      # A mixed-outcome batch (HTTP 207) returns normally — inspect each entry's
      # `status` in `data`; it does not raise.
      def send_batch(batch, idempotency_key = nil)
        body = batch.dup
        body[:defaults] = encode_attachments(batch[:defaults]) if batch[:defaults]
        body[:emails] = Array(batch[:emails]).map { |email| encode_attachments(email) }
        request_object(:post, "/email/batch",
          body: body, idempotent: true, idempotency_key: idempotency_key)
      end

      private

      def encode_attachments(message)
        attachments = message[:attachments]
        return message unless attachments.is_a?(Array)

        message = message.dup
        message[:attachments] = attachments.map do |attachment|
          content = attachment[:content]
          next attachment unless content.is_a?(String)

          attachment.merge(content: [content].pack("m0"))
        end
        message
      end
    end
  end
end
