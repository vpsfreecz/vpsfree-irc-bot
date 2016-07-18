module VpsFree::Irc::Bot
  class Base
    include Cinch::Plugin
    include Command

    listen_to :private, method: :not_found

    command :help do
      desc 'show this message'
      channel false
    end

    command :ping do
      desc 'play a game of ping pong'
      channel false
    end

    def cmd_help(m, channel)
      help = <<END
! vpsFree.vz IRC Bot v#{VERSION}
! ====================#{'=' * VERSION.size}
!
! Channel commands:
END

      Command.commands.each do |cmd|
        help += "! " + " "*4 + cmd.help(:channel, false) + "\n"
      end
      
      help += "!\n! Private commands:\n"
      
      Command.commands.each do |cmd|
        help += "! " + " "*4 + cmd.help(:private, bot.channel_list.count > 1) + "\n"
      end

      m.user.send(help)
    end

    def cmd_ping(m, channel)
      m.reply('pong')
    end

    def not_found(m)
      Command.commands.each do |cmd|
        return if /^!?#{cmd.name}/ =~ m.message
      end

      m.reply("Command '#{m.message}' not found. Say 'help' to get a list of commands.")
    end
  end
end
