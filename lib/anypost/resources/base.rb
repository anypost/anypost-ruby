# frozen_string_literal: true

require "erb"

module Anypost
  module Resources
    # Shared base for the API resources: holds the transport, wraps decoded
    # object responses as {Response} instances, and builds {Page}s.
    #
    # @api private
    class Base
      def initialize(http)
        @http = http
      end

      private

      def request_object(method, path, **opts)
        decoded = @http.request(method, path, **opts)
        Response.new(decoded.is_a?(Hash) ? decoded : {})
      end

      def paginate(path, query)
        decoded = @http.request(:get, path, query: query)
        Page.new(decoded.is_a?(Hash) ? decoded : {}) do |after|
          paginate(path, query.merge(after: after))
        end
      end

      # Percent-encode a path segment (encodes "/", "@", "*", etc.).
      def encode(segment)
        ERB::Util.url_encode(segment.to_s)
      end
    end
  end
end
