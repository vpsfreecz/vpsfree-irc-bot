require 'json'
require 'sinatra'

module VpsFree::Irc::Bot
  module GitHubWebHook ; end
end

require_relative 'github_webhook/event'
require_relative 'github_webhook/announcer'
require_relative 'github_webhook/server'
