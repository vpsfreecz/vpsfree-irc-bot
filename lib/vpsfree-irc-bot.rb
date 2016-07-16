require 'cinch'

module VpsFree
  module Irc
    module Bot ; end
  end
end

require_relative 'vpsfree-irc-bot/channel_log'
require_relative 'vpsfree-irc-bot/channel_lastlog'
require_relative 'vpsfree-irc-bot/template_logger'
require_relative 'vpsfree-irc-bot/version'

module VpsFree::Irc::Bot
  NAME = 'vpsfbot'

  def self.new
    Cinch::Bot.new do
      configure do |c|
        c.server = 'chat.freenode.net'
        c.channels = ['#vpsfree']
        c.nick = NAME
        c.plugins.plugins = [
            ChannelLog,
            ChannelLastLog,
        ]
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

  def self.start
    new.start
  end
end
