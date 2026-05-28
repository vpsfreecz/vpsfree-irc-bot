# frozen_string_literal: true

require 'bundler/setup'
require 'rspec'

$:.unshift(File.expand_path('../lib', __dir__))

require 'vpsfree-irc-bot'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end

