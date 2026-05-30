# frozen_string_literal: true

module Anypost
  module Resources
    # Operations on the `/templates` endpoints, including the draft/publish flow.
    class Templates < Base
      # List the team's templates, newest-first.
      def list(params = {})
        paginate("/templates", {limit: params[:limit], after: params[:after]})
      end

      # Create a template. It starts unpublished — publish it before sending.
      def create(params)
        request_object(:post, "/templates", body: params)
      end

      # Retrieve a template, including its published content.
      def get(id)
        request_object(:get, "/templates/#{encode(id)}")
      end

      # Update a template's `name`. Body content lives on the draft.
      def update(id, params)
        request_object(:patch, "/templates/#{encode(id)}", body: params)
      end

      # Permanently delete a template.
      def delete(id)
        @http.request(:delete, "/templates/#{encode(id)}")
        nil
      end

      # Copy a template. The copy starts unpublished with a draft seeded from the
      # source's current editable content, and must be published before sending.
      def duplicate(id, params = {})
        request_object(:post, "/templates/#{encode(id)}/duplicate",
          body: params.empty? ? nil : params)
      end

      # Retrieve the template's unpublished draft. Raises not_found if none exists.
      def get_draft(id)
        request_object(:get, "/templates/#{encode(id)}/draft")
      end

      # Create or update the template's draft. Idempotent upsert; published content untouched.
      def update_draft(id, params)
        request_object(:patch, "/templates/#{encode(id)}/draft", body: params)
      end

      # Discard the template's draft without touching published content.
      def delete_draft(id)
        @http.request(:delete, "/templates/#{encode(id)}/draft")
        nil
      end

      # Promote the draft into the published slot, consuming the draft.
      def publish(id)
        request_object(:post, "/templates/#{encode(id)}/publish")
      end
    end
  end
end
