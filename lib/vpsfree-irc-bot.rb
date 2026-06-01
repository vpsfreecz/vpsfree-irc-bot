require 'cinch'
require 'require_all'

module VpsFree
  module Irc
    module Bot; end
  end
end

require_rel 'vpsfree-irc-bot/*.rb'

module VpsFree::Irc::Bot
  NAME = 'vpsfbot'.freeze

  # @param label [String] server label
  # @param host [String] actual address/hostname to connect to
  # @param channels [Array<String>]
  # @param opts [Hash]
  # @option opts [String] nick
  # @option opts [String] archive_url
  # @option opts [String] archive_dst
  # @option opts [String] api_url
  def self.new(label, host, channels, opts = {})
    opts = normalize_opts(opts)
    nick = opts[:nick] || NAME

    # Initialize storage to avoid later thread collisions
    UserStorage.init(opts[:state_dir], label)

    DiscourseWebHook::Server.start(opts[:discourse_webhook]) if configured_hash?(opts[:discourse_webhook])
    GitHubWebHook::Server.start(opts[:github_webhook]) if configured_hash?(opts[:github_webhook])

    plugins = configured_plugins(opts)
    plugin_options = configured_plugin_options(label, nick, channels, opts)

    Cinch::Bot.new do
      configure do |c|
        c.server = host
        c.channels = channels
        c.nick = nick
        c.realname = 'vpsFree.cz IRC Bot'
        c.plugins.plugins = plugins
        c.plugins.options = plugin_options
      end
    end
  end

  def self.normalize_opts(opts)
    opts || {}
  end

  def self.configured_hash?(value)
    value.is_a?(Hash) && !value.empty?
  end

  def self.configured_array?(value)
    value.is_a?(Array) && !value.empty?
  end

  def self.api_enabled?(opts)
    opts[:api_url] && !opts[:api_url].empty?
  end

  def self.easter_eggs_enabled?(opts)
    return false if ENV.fetch('VPSFREE_IRC_BOT_EASTER_EGGS', nil) == '0'

    opts.fetch(:easter_eggs, true)
  end

  def self.configured_plugins(opts)
    plugins = [
      Base,
      ChannelLog,
      ChannelLastLog,
      Uptime,
      Rank,
      UrlMarker,
      Greeter,
      KeepNick,
      KeepChannels,
      Mute
    ]

    if api_enabled?(opts)
      plugins << Cluster
      plugins << WebEventLog if configured_hash?(opts[:web_event_log])
      plugins << OutageReports if configured_hash?(opts[:outage_reports])
      plugins << EasterEggs if easter_eggs_enabled?(opts)
    end

    plugins << DokuWiki if configured_array?(opts[:dokuwiki])
    plugins << BlogFeed if configured_hash?(opts[:blog])
    plugins << Forecast if configured_hash?(opts[:forecast])
    plugins << DiscourseWebHook::Announcer if configured_hash?(opts[:discourse_webhook])
    plugins << GitHubWebHook::Announcer if configured_hash?(opts[:github_webhook])
    plugins
  end

  def self.configured_plugin_options(label, nick, channels, opts)
    ret = {
      ChannelLog => {
        server_label: label,
        archive_url: opts[:archive_url],
        archive_dst: opts[:archive_dst]
      },
      Base => {
        nickserv: opts[:nickserv]
      },
      UrlMarker => opts[:url_marker],
      KeepNick => {
        nick: nick
      },
      KeepChannels => {
        channels: channels
      }
    }

    if api_enabled?(opts)
      ret[Cluster] = { api_url: opts[:api_url] }
      ret[WebEventLog] = opts[:web_event_log].merge(api_url: opts[:api_url]) if configured_hash?(opts[:web_event_log])
      if configured_hash?(opts[:outage_reports])
        ret[OutageReports] = opts[:outage_reports].merge(
          server_label: label,
          api_url: opts[:api_url],
          state_dir: opts[:state_dir]
        )
      end
      ret[EasterEggs] = { api_url: opts[:api_url] } if easter_eggs_enabled?(opts)
    end

    ret[DokuWiki] = { wikis: opts[:dokuwiki] } if configured_array?(opts[:dokuwiki])
    ret[BlogFeed] = opts[:blog] if configured_hash?(opts[:blog])
    ret[Forecast] = opts[:forecast] if configured_hash?(opts[:forecast])
    if configured_hash?(opts[:discourse_webhook])
      ret[DiscourseWebHook::Announcer] = {
        channels: opts[:discourse_webhook][:channels]
      }
    end
    if configured_hash?(opts[:github_webhook])
      ret[GitHubWebHook::Announcer] = {
        channels: GitHubWebHook::Announcer.normalize_channels(
          opts[:github_webhook][:channels]
        )
      }
    end
    ret
  end

  def self.start(*)
    bot = new(*)

    do_exit = proc do
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
