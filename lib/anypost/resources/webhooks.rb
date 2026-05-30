# frozen_string_literal: true

module Anypost
  module Resources
    # Operations on the `/webhooks` endpoints.
    class Webhooks < Base
      # List the team's webhooks, newest-first.
      def list(params = {})
        paginate("/webhooks", {limit: params[:limit], after: params[:after]})
      end

      # Create a webhook. The full `signing_secret` is on the response to this
      # call only — store it now to verify future deliveries; later reads return
      # only the prefix.
      def create(params)
        request_object(:post, "/webhooks", body: params)
      end

      # Retrieve a webhook. The signing secret is never returned — only its prefix.
      def get(id)
        request_object(:get, "/webhooks/#{encode(id)}")
      end

      # Update a webhook's name, URL, subscribed events, and status. This does not
      # rotate the signing secret — use {#rotate_secret}.
      def update(id, params)
        request_object(:patch, "/webhooks/#{encode(id)}", body: params)
      end

      # Permanently delete a webhook.
      def delete(id)
        @http.request(:delete, "/webhooks/#{encode(id)}")
        nil
      end

      # Send one synthetic `webhook.test` event and report the outcome. One-shot,
      # not retried, and absent from delivery history. Returns the result even
      # when the endpoint fails — read `delivered` and `status_code`.
      def test(id)
        request_object(:post, "/webhooks/#{encode(id)}/test")
      end

      # Rotate the signing secret. The new secret is on this response only. The
      # previous secret stays valid for a 24h grace window. Rotating again before
      # the window ends raises webhook_rotation_in_progress (a {ConflictError}).
      def rotate_secret(id)
        request_object(:post, "/webhooks/#{encode(id)}/rotate-secret")
      end
    end
  end
end
