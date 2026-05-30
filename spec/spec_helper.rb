# frozen_string_literal: true

require "anypost"
require "json"
require "faraday"

require_relative "support/test_server"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand(config.seed)

  config.include TestServerHelper
end
