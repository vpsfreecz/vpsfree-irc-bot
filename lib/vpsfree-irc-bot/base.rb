module VpsFree::Irc::Bot
  class Base
    include Cinch::Plugin
    include Command

    listen_to :connect, method: :connect
    listen_to :channel, method: :channel_not_found
    listen_to :private, method: :not_found

    command :help do
      desc 'show this message'
      channel false
    end

    command :ping do
      desc 'play a game of ping pong'
      channel false
    end

    def connect(m)
      return unless bot.config.nickserv

      User('NickServ').send("identify #{bot.config.nickserv}")
    end

    def cmd_help(m, channel)
      help = <<END
! vpsFree.vz IRC Bot v#{VERSION}
! ====================#{'=' * VERSION.size}
!
! Channel commands:
END

      cmds = Command.commands.sort { |a, b| a.name <=> b.name }

      cmds.each do |cmd|
        help += "! " + " "*4 + cmd.help(:channel, false) + "\n"
      end
      
      help += "!\n! Private commands:\n"
      
      cmds.each do |cmd|
        help += "! " + " "*4 + cmd.help(:private, bot.channel_list.count > 1) + "\n"
      end

      m.user.send(help)
    end

    def cmd_ping(m, channel)
      m.reply('pong')
    end

    def channel_not_found(m)
      return if /^(#{bot.nick}[:|,|\s])/ !~ m.message

      cmd_str = m.message[$1.size .. -1].strip

      Command.commands.each do |cmd|
        return if /!?#{cmd.name}/ =~ cmd_str || /^!?#{cmd.name}/ =~ cmd_str
      end
      
      m.reply("Command '#{cmd_str}' not found. Say 'help' to get a list of commands.")
    end

    def not_found(m)
      # Skip server init
      return if m.target.nil?

      Command.commands.each do |cmd|
        return if /^!?#{cmd.name}/ =~ m.message
      end

      m.reply("Command '#{m.message}' not found. Say 'help' to get a list of commands.")
    end
  end
end
