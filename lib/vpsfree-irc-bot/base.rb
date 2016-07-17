module VpsFree::Irc::Bot
  class Base
    include Cinch::Plugin
    include Command

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
        help += "! " + " "*4 + cmd.help(:channel) + "\n"
      end
      
      help += "!\n! Private commands:\n"
      
      Command.commands.each do |cmd|
        help += "! " + " "*4 + cmd.help(:private) + "\n"
      end

      m.user.send(help)
    end

    def cmd_ping(m, channel)
      m.reply('pong')
    end
  end
end
