# frozen_string_literal: true

module Anypost
  module Resources
    # Identity operations (`/whoami`).
    class Identity < Base
      # Identify the team and permission level behind the current API key.
      def whoami
        request_object(:get, "/whoami")
      end
    end
  end
end
