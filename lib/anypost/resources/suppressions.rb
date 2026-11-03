# frozen_string_literal: true

module Anypost
  module Resources
    # Operations on the `/suppressions` endpoints. Entries key on `(email, topic)`.
    class Suppressions < Base
      # List the team's suppressions, newest-first.
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

      # Add up to 1,000 suppressions in one call. Pass the list of items, each a
      # hash with `email` and optionally `topic` (default `*`), `reason` (a free-form
      # string; common aliases like `bounce` or `opt-out` are mapped, anything else
      # records `manual`), and `note`. Entries that already exist are counted in
      # `already_suppressed` and left unchanged, so a batch is safe to retry.
      # Invalid addresses come back in `invalid` (with their `index` and `email`)
      # instead of failing the batch. Raises validation_error, adding nothing, if
      # the batch would pass the team's suppression limit.
      #
      # @return [Response] with `imported`, `already_suppressed`, and `invalid`
      def create_batch(suppressions)
        request_object(:post, "/suppressions/batch", body: {suppressions: suppressions})
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
