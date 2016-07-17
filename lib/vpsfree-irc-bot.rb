require 'cinch'

module VpsFree
  module Irc
    module Bot ; end
  end
end

require_relative 'vpsfree-irc-bot/command'
require_relative 'vpsfree-irc-bot/base'
require_relative 'vpsfree-irc-bot/channel_log'
require_relative 'vpsfree-irc-bot/channel_lastlog'
require_relative 'vpsfree-irc-bot/template_logger'
require_relative 'vpsfree-irc-bot/html_logger'
require_relative 'vpsfree-irc-bot/version'

module VpsFree::Irc::Bot
  NAME = 'vpsfbot'

  # @param server [String]
  # @param channels [Array<String>]
  # @param opts [Hash]
  # @option opts [String] nick
  # @option opts [String] archive_url
  # @option opts [String] archive_dst
  def self.new(server, channels, opts = {})
    Cinch::Bot.new do
      configure do |c|
        c.server = server
        c.channels = channels
        c.nick = opts[:nick] || NAME
        c.plugins.plugins = [
            Base,
            ChannelLog,
            ChannelLastLog,
        ]
        c.messages_per_second = 10
        c.archive_url = opts[:archive_url]
        c.archive_dst = opts[:archive_dst]
      end
    end
  end

  def self.start(*args)
    new(*args).start
  end
end
