# frozen_string_literal: true

module Anypost
  module Resources
    # Read access to the `/events` stream. List-only — events are not addressable by id.
    class Events < Base
      # Page through the team's events, newest-first.
      #
      # The window defaults to the last 24 hours and is clamped to the plan's
      # retention. Filter with `start`, `end`, `event_type`, `recipient`,
      # `email_id`, `message_id`, `domain`, `topic`, `campaign`, `template_id`,
      # `ip_pool`, and `tags` (an array, matched with hasAny).
      def list(params = {})
        tags = params[:tags]
        paginate("/events", {
          limit: params[:limit],
          after: params[:after],
          start: params[:start],
          end: params[:end],
          event_type: params[:event_type],
          recipient: params[:recipient],
          email_id: params[:email_id],
          message_id: params[:message_id],
          domain: params[:domain],
          topic: params[:topic],
          campaign: params[:campaign],
          template_id: params[:template_id],
          # Exact match against the [a-z0-9]([a-z0-9-]*[a-z0-9])? pool-name
          # shape. A value outside it returns an empty list rather than being
          # ignored, so a typo cannot silently widen the answer to "all pools".
          ip_pool: params[:ip_pool],
          # Sent comma-separated (tags=a,b); the API matches with hasAny.
          tags: (tags.is_a?(Array) && !tags.empty?) ? tags.join(",") : nil
        })
      end
    end
  end
end
