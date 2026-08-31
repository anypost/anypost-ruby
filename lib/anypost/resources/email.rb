# frozen_string_literal: true

module Anypost
  module Resources
    # Operations on the `/email` endpoints.
    #
    # Give each attachment its content exactly one of two ways: `content` for raw
    # file bytes (e.g. from `File.binread`), which the SDK base64-encodes for
    # transport, or `content_base64` for content that is already base64 at rest,
    # which is sent through verbatim so nothing is decoded just to be re-encoded.
    # Ruby has no type-level distinction between the two — both are Strings — so
    # the key you choose is the signal.
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
        message[:attachments] = attachments.map { |attachment| encode_attachment(attachment) }
        message
      end

      # Collapse an attachment's two possible content keys onto the single
      # base64 `content` field the API takes.
      def encode_attachment(attachment)
        return attachment unless attachment.is_a?(Hash)

        raw = attachment[:content]
        encoded = attachment[:content_base64]

        if raw && encoded
          raise ArgumentError,
            "attachment #{attachment[:filename].inspect} sets both :content and " \
            ":content_base64; set exactly one"
        end

        return attachment.except(:content_base64).merge(content: encoded) if encoded
        return attachment.merge(content: [raw].pack("m0")) if raw.is_a?(String)

        raise ArgumentError,
          "attachment #{attachment[:filename].inspect} has no content; set :content " \
          "(raw bytes) or :content_base64"
      end
    end
  end
end
