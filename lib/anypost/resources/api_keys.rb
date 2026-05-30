# frozen_string_literal: true

module Anypost
  module Resources
    # Operations on the `/api-keys` endpoints.
    class ApiKeys < Base
      # List the team's API keys, newest-first.
      def list(params = {})
        paginate("/api-keys", {limit: params[:limit], after: params[:after]})
      end

      # Issue a new API key.
      #
      # The plaintext secret is returned only in this response, as `key` — store
      # it securely; it cannot be retrieved later.
      def create(params)
        request_object(:post, "/api-keys", body: params)
      end

      # Retrieve a single API key's metadata. The secret is never returned.
      def get(id)
        request_object(:get, "/api-keys/#{encode(id)}")
      end

      # Update a key's name, permissions, and restrictions. The secret is not
      # rotated here. Changes may take up to 5 minutes to propagate.
      def update(id, params)
        request_object(:patch, "/api-keys/#{encode(id)}", body: params)
      end

      # Delete a key. It may keep authenticating for up to 5 minutes (gateway cache).
      def delete(id)
        @http.request(:delete, "/api-keys/#{encode(id)}")
        nil
      end
    end
  end
end
