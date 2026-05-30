# frozen_string_literal: true

require_relative "anypost/version"
require_relative "anypost/errors"
require_relative "anypost/response"
require_relative "anypost/page"
require_relative "anypost/webhook_signature"
require_relative "anypost/http_client"
require_relative "anypost/resources/base"
require_relative "anypost/resources/email"
require_relative "anypost/resources/domains"
require_relative "anypost/resources/api_keys"
require_relative "anypost/resources/templates"
require_relative "anypost/resources/suppressions"
require_relative "anypost/resources/webhooks"
require_relative "anypost/resources/events"
require_relative "anypost/resources/identity"
require_relative "anypost/client"

# Official Ruby SDK for the Anypost email API.
module Anypost
end
