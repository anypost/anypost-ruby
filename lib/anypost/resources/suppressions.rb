# frozen_string_literal: true

module Anypost
  module Resources
    # Operations on the `/suppressions` endpoints. Entries key on `(email, topic)`.
    class Suppressions < Base
      # List the team's suppressions, newest-first. Expired rows are filtered out.
      # Filter with `email_contains`, `topic`, `reason`, and `origin`.
      def list(params = {})
        paginate("/suppressions", {
          limit: params[:limit],
          after: params[:after],
          email_contains: params[:email_contains],
          topic: params[:topic],
          reason: params[:reason],
          origin: params[:origin]
        })
      end

      # Add a manual suppression. Defaults to topic `*` (every topic). Raises
      # validation_error if an active entry for the same `(email, topic)` exists.
      def create(params)
        request_object(:post, "/suppressions", body: params)
      end

      # Retrieve the suppression for an `(email, topic)` pair. Use `*` as the
      # topic for the global row. Raises not_found if the pair isn't suppressed.
      def get(email, topic)
        request_object(:get, "/suppressions/#{encode(email)}/#{encode(topic)}")
      end

      # Remove the single `(email, topic)` row. Other topics are untouched.
      def delete(email, topic)
        @http.request(:delete, "/suppressions/#{encode(email)}/#{encode(topic)}")
        nil
      end

      # List every suppression on file for an address, across all topics. Raises
      # not_found if the address has no active suppressions.
      #
      # @return [Array<Response>]
      def list_for_email(email)
        decoded = @http.request(:get, "/suppressions/#{encode(email)}")
        data = decoded.is_a?(Hash) ? decoded["data"] : nil
        Array(data).map { |row| Response.wrap(row) }
      end

      # Remove an address from the suppression list across every topic.
      def delete_for_email(email)
        @http.request(:delete, "/suppressions/#{encode(email)}")
        nil
      end
    end
  end
end
