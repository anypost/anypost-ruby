# frozen_string_literal: true

require_relative "lib/anypost/version"

Gem::Specification.new do |spec|
  spec.name = "anypost"
  spec.version = Anypost::VERSION
  spec.authors = ["Anypost"]
  spec.email = ["support@anypost.com"]

  spec.summary = "Official Ruby SDK for the Anypost email API."
  spec.description = "Send email, manage domains, templates, webhooks, and suppressions, " \
                     "and read the event stream through the Anypost HTTP API."
  spec.homepage = "https://anypost.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/anypost/anypost-ruby",
    "bug_tracker_uri" => "https://github.com/anypost/anypost-ruby/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
end
