require 'cinch'
require 'vpsfree-irc-bot/command'
require 'vpsfree-irc-bot/helpers'

module VpsFree::Irc::Bot
  class Base
    include Cinch::Plugin
    include Command
    include Helpers

    listen_to :connect, method: :connect
    listen_to :channel, method: :channel_not_found
    listen_to :private, method: :not_found

    command :help do
      aliases :commands, :command_list
      desc 'show help'
      channel false
      arg :command, required: false
    end

    command :ping do
      desc 'play a game of ping pong'
      channel false
    end

    def connect(_m)
      return unless config[:nickserv]

      User('NickServ').send("identify #{config[:nickserv]}")
    end

    def cmd_help(m, channel, cmd = nil)
      help = Help.new(bot, Command.commands)

      if cmd
        help << "Command #{cmd}\n\n"

        begin
          help.command(cmd.to_sym)
        rescue ArgumentError => e
          m.user.send(e.message)
        end

      else
        help << <<~END
          vpsFree.cz IRC Bot v#{VERSION}
          ====================#{'=' * VERSION.size}
          #{'  '}
        END

        if channel
          help << "Channel commands:\n"
          help.commands(:channel)

        else
          help << "Private commands:\n"
          help.commands(:private)
        end

        help << "\nUse !help <command> to get help for a specific command."
      end

      m.user.send(help)
    end

    def cmd_ping(m, _channel)
      reply(m, 'pong')
    end

    def channel_not_found(m)
      return if /^(#{bot.nick}[:|,\s])/ !~ m.message

      cmd_str = m.message[::Regexp.last_match(1).size..].strip

      return if known_channel_command?(cmd_str)

      reply(m, "Command '#{cmd_str}' not found. Say 'help' to get a list of commands.")
    end

    def not_found(m)
      # Skip server init
      return if m.target.nil?

      # Ignore messages from NickServ
      return if m.user.nick == 'NickServ'

      return if known_private_command?(m.message)

      reply(m, "Command '#{m.message}' not found. Say 'help' to get a list of commands.")
    end

    protected

    def known_channel_command?(cmd_str)
      Command.commands.any? do |cmd|
        cmd.names.any? do |n|
          /!?#{n}/ =~ cmd_str || /^!?#{n}/ =~ cmd_str
        end
      end
    end

    def known_private_command?(message)
      Command.commands.any? do |cmd|
        cmd.names.any? { |n| /^!?#{n}/ =~ message }
      end
    end
  end
end
