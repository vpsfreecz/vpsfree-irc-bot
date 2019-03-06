require 'cinch'
require 'vpsfree-irc-bot/command'
require 'vpsfree-irc-bot/helpers'

module VpsFree::Irc::Bot
  class Greeter
    include Cinch::Plugin
    include Command
    include Helpers

    command :greet do
      desc 'introduce a new user to vpsFree.cz'
      arg :user, required: true
    end

    def cmd_greet(m, channel, nick)
      if nick == bot.nick
        reply(m, "I'd rather not, people would think that I'm crazy.")
        return

      elsif m.user.nick == nick
        reply(m, "I doubt that's necessary.")
        return
      end

      user = channel.users.keys.detect { |u| u.nick == nick }

      if user.nil?
        reply(m, "User '#{nick}' is not in channel '#{channel}'")
        return
      end

      log_send(
          channel,
          <<END
#{user.nick}: Hi, welcome to #{channel}.
This channel is for members of vpsFree.cz, a non-profit organization that provides VPS for its members.
The membership fee is 12 EUR / 300 CZK per month, for which you get access to the VPS and other perks.
In short, the VPS has 8 CPUs, 4 GB RAM, 120 GB disk, 300 Mbps link and is backed-up daily.
For more information, please see https://vpsfree.cz. Since I'm a bot, however intelligent, don't ask me any questions :)
END
      )
    end
  end
end
