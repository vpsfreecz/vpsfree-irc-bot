require 'cinch'
require 'require_all'

module VpsFree
  module Irc
    module Bot ; end
  end
end

require_rel 'vpsfree-irc-bot/*.rb'

module VpsFree::Irc::Bot
  NAME = 'vpsfbot'

  # @param label [String] server label
  # @param host [String] actual address/hostname to connect to
  # @param channels [Array<String>]
  # @param opts [Hash]
  # @option opts [String] nick
  # @option opts [String] archive_url
  # @option opts [String] archive_dst
  # @option opts [String] api_url
  def self.new(label, host, channels, opts = {})
    # Initialize storage to avoid later thread collisions
    UserStorage.init(opts[:state_dir], label)

    DiscourseWebHook::Server.start(opts[:discourse_webhook])
    GitHubWebHook::Server.start(opts[:github_webhook])

    Cinch::Bot.new do
      configure do |c|
        c.server = host
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
          KeepChannels,
          Mute,
          OutageReports,
          Forecast,
          EasterEggs,
          DiscourseWebHook::Announcer,
          GitHubWebHook::Announcer,
        ]

        c.plugins.options = {
          Cluster => {
            api_url: opts[:api_url],
          },
          WebEventLog => {
            api_url: opts[:api_url],
            channels: opts[:web_event_log][:channels],
          },
          ChannelLog => {
            server_label: label,
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
          BlogFeed => opts[:blog],
          KeepNick => {
            nick: c.nick,
          },
          KeepChannels => {
            channels: channels,
          },
          OutageReports => {
            server_label: label,
            api_url: opts[:api_url],
            channels: opts[:outage_reports][:channels],
            state_dir: opts[:state_dir],
          },
          Forecast => opts[:forecast],
          EasterEggs => {
            api_url: opts[:api_url],
          },
          DiscourseWebHook::Announcer => {
            channels: opts[:discourse_webhook][:channels]
          },
          GitHubWebHook::Announcer => {
            channels: Hash[opts[:github_webhook][:channels].map do |k, v|
              [k.to_s, v]
            end],
          },
        }
      end
    end
  end

  def self.start(*args)
    bot = new(*args)

    do_exit = Proc.new do
      # bot.quit must be executed in a new thread, as it cannot synchronize
      # mutexes in a trap context.
      Thread.new { bot.quit('So long, and thanks for all the fish') }
    end

    Signal.trap('TERM', &do_exit)
    Signal.trap('INT', &do_exit)

    DayChange.start
    bot.start
  end
end
