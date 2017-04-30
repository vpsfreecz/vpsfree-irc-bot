require 'cinch'

module VpsFree
  module Irc
    module Bot ; end
  end
end

require_relative 'vpsfree-irc-bot/state'
require_relative 'vpsfree-irc-bot/helpers'
require_relative 'vpsfree-irc-bot/api'
require_relative 'vpsfree-irc-bot/multi_line'
require_relative 'vpsfree-irc-bot/day_change'
require_relative 'vpsfree-irc-bot/command'
require_relative 'vpsfree-irc-bot/persistence'
require_relative 'vpsfree-irc-bot/file_storage'
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
require_relative 'vpsfree-irc-bot/mailman'
require_relative 'vpsfree-irc-bot/mailing_lists'
require_relative 'vpsfree-irc-bot/greeter'
require_relative 'vpsfree-irc-bot/dokuwiki'
require_relative 'vpsfree-irc-bot/blog_feed'
require_relative 'vpsfree-irc-bot/keep_nick'
require_relative 'vpsfree-irc-bot/outage_reports'
require_relative 'vpsfree-irc-bot/mute'
require_relative 'vpsfree-irc-bot/forecast'
require_relative 'vpsfree-irc-bot/help'
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
    UserStorage.init(server)

    Cinch::Bot.new do
      configure do |c|
        c.server = server
        c.channels = channels
        c.nick = opts[:nick] || NAME
        c.realname = 'vpsFree.cz IRC Bot'
        c.plugins.plugins = [
            Base,
            ChannelLog,
            ChannelLastLog,
            Cluster,
            Uptime,
            Rank,
            UrlMarker,
            WebEventLog,
            MailingLists,
            Greeter,
            DokuWiki,
            BlogFeed,
            KeepNick,
            Mute,
            OutageReports,
            Forecast,
        ]

        c.plugins.options = {
            Cluster => {
                api_url: opts[:api_url],
            },
            WebEventLog => {
                api_url: opts[:api_url],
            },
            ChannelLog => {
                archive_url: opts[:archive_url],
                archive_dst: opts[:archive_dst],
            },
            Base => {
                nickserv: opts[:nickserv],
            },
            UrlMarker => opts[:url_marker],
            MailingLists => opts[:mailing_lists],
            DokuWiki => {
                wikis: opts[:dokuwiki],
            },
            BlogFeed => {
                url: opts[:blog_feed],
            },
            KeepNick => {
                nick: c.nick,
            },
            OutageReports => {
                api_url: opts[:api_url],
            },
            Forecast => opts[:forecast],
        }
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
