require 'cinch'

module VpsFree
  module Irc
    module Bot ; end
  end
end

require_relative 'vpsfree-irc-bot/helpers'
require_relative 'vpsfree-irc-bot/multi_line'
require_relative 'vpsfree-irc-bot/day_change'
require_relative 'vpsfree-irc-bot/command'
require_relative 'vpsfree-irc-bot/user_storage'
require_relative 'vpsfree-irc-bot/base'
require_relative 'vpsfree-irc-bot/channel_log'
require_relative 'vpsfree-irc-bot/channel_lastlog'
require_relative 'vpsfree-irc-bot/template_logger'
require_relative 'vpsfree-irc-bot/html_logger'
require_relative 'vpsfree-irc-bot/yml_logger'
require_relative 'vpsfree-irc-bot/cluster'
require_relative 'vpsfree-irc-bot/uptime'
require_relative 'vpsfree-irc-bot/rank'
require_relative 'vpsfree-irc-bot/url_marker'
require_relative 'vpsfree-irc-bot/web_event_log'
require_relative 'vpsfree-irc-bot/outage_report'
require_relative 'vpsfree-irc-bot/version'

module VpsFree::Irc::Bot
  NAME = 'vpsfbot'

  # @param server [String]
  # @param channels [Array<String>]
  # @param opts [Hash]
  # @option opts [String] nick
  # @option opts [String] archive_url
  # @option opts [String] archive_dst
  # @option opts [String] api_url
  def self.new(server, channels, opts = {})
    # Initialize storage to avoid later thread collisions
    UserStorage.instance

    Cinch::Bot.new do
      configure do |c|
        c.server = server
        c.channels = channels
        c.nick = opts[:nick] || NAME
        c.plugins.plugins = [
            Base,
            ChannelLog,
            ChannelLastLog,
            Cluster,
            Uptime,
            Rank,
            UrlMarker,
            WebEventLog,
            OutageReport,
        ]
        c.archive_url = opts[:archive_url]
        c.archive_dst = opts[:archive_dst]
        c.api_url = opts[:api_url]
        c.webui_url = opts[:webui_url]
        c.nickserv = opts[:nickserv]
        c.outage_mail = opts[:outage_mail]
      end
    end
  end

  def self.start(*args)
    bot = new(*args)

    exit = Proc.new do
      # bot.quit must be executed in a new thread, as it cannot synchronize
      # mutexes in a trap context.
      Thread.new { bot.quit('So long, and thanks for all the fish') }
    end

    Signal.trap('TERM', &exit)
    Signal.trap('INT', &exit)
    
    DayChange.start
    bot.start
  end
end
