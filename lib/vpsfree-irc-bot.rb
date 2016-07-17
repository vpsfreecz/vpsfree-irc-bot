require 'cinch'

module VpsFree
  module Irc
    module Bot ; end
  end
end

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
            ChannelLog,
            ChannelLastLog,
        ]
        c.archive_url = opts[:archive_url]
        c.archive_dst = opts[:archive_dst]
      end

      on :private, :help do |m|
        help = <<END
! vpsFree.vz IRC Bot v#{VERSION}
! ====================#{'=' * VERSION.size}
! All commands must be sent to the bot as a PM, e.g.
!
!   /msg #{NAME} <command>
!
! Commands:
!
!    help             show this message
!    lastlog [N]      print N last messages, defaults to 20
END
        m.reply(help)
      end

      on :private, :ping do |m|
        m.reply('pong')
      end
    end
  end

  def self.start(*args)
    new(*args).start
  end
end
