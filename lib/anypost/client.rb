# frozen_string_literal: true

module Anypost
  # Client for the Anypost email API.
  #
  #   require "anypost"
  #
  #   client = Anypost::Client.new("ap_your_api_key") # or Anypost::Client.new to read ANYPOST_API_KEY
  #   email = client.email.send(
  #     from: "Acme <you@yourdomain.com>",
  #     to: ["someone@example.com"],
  #     subject: "Hello",
  #     html: "<p>It worked.</p>"
  #   )
  #   email.id
  class Client
    DEFAULT_BASE_URL = "https://api.anypost.com/v1"
    DEFAULT_TIMEOUT = 30
    DEFAULT_MAX_RETRIES = 2

    # @return [Resources::Email] send operations (`/email`, `/email/batch`)
    attr_reader :email
    # @return [Resources::Domains] sending-domain operations (`/domains`)
    attr_reader :domains
    # @return [Resources::ApiKeys] API-key operations (`/api-keys`)
    attr_reader :api_keys
    # @return [Resources::Templates] template operations, including draft/publish
    attr_reader :templates
    # @return [Resources::Suppressions] suppression-list operations (`/suppressions`)
    attr_reader :suppressions
    # @return [Resources::Webhooks] webhook operations, including test and rotation
    attr_reader :webhooks
    # @return [Resources::Events] read access to the event stream (`/events`)
    attr_reader :events

    # @param api_key [String, nil] defaults to the ANYPOST_API_KEY environment variable
    def initialize(api_key = nil, base_url: DEFAULT_BASE_URL, timeout: DEFAULT_TIMEOUT,
      max_retries: DEFAULT_MAX_RETRIES, default_headers: {}, connection: nil, sleeper: nil, jitter: nil)
      key = api_key
      key = ENV["ANYPOST_API_KEY"] if key.nil? || key.empty?
      if key.nil? || key.empty?
        raise ArgumentError,
          "An Anypost API key is required. Pass it to the constructor or set ANYPOST_API_KEY."
      end

      http = HttpClient.new(
        api_key: key,
        base_url: base_url,
        timeout: timeout,
        max_retries: max_retries,
        default_headers: default_headers,
        connection: connection,
        sleeper: sleeper,
        jitter: jitter
      )

      @email = Resources::Email.new(http)
      @domains = Resources::Domains.new(http)
      @api_keys = Resources::ApiKeys.new(http)
      @templates = Resources::Templates.new(http)
      @suppressions = Resources::Suppressions.new(http)
      @webhooks = Resources::Webhooks.new(http)
      @events = Resources::Events.new(http)
      @identity = Resources::Identity.new(http)
    end

    # Identify the team and permission level behind the current API key.
    def whoami
      @identity.whoami
    end
  end
end
