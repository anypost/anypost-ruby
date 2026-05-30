# frozen_string_literal: true

module Anypost
  module Resources
    # Operations on the `/domains` endpoints.
    class Domains < Base
      # List the team's domains, newest-first. Returns a {Page}; iterate it to
      # walk every page, or follow `page.next_cursor` yourself.
      def list(params = {})
        paginate("/domains", {limit: params[:limit], after: params[:after]})
      end

      # Add a sending domain. The returned domain is `pending` until verified.
      def create(params)
        request_object(:post, "/domains", body: params)
      end

      # Retrieve a single domain by id.
      def get(id)
        request_object(:get, "/domains/#{encode(id)}")
      end

      # Update a domain's tracking configuration. The domain `name` is immutable.
      def update(id, params)
        request_object(:patch, "/domains/#{encode(id)}", body: params)
      end

      # Permanently delete a domain and its DKIM keys.
      def delete(id)
        @http.request(:delete, "/domains/#{encode(id)}")
        nil
      end

      # Trigger a verification check.
      #
      # Always returns the current domain — read `status` and
      # `verification_failure` to learn the outcome; a still-`pending` domain
      # does not raise. Safe to poll while DNS propagates.
      def verify(id)
        request_object(:post, "/domains/#{encode(id)}/verify")
      end
    end
  end
end
