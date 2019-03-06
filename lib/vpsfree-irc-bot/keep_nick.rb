require 'cinch'

module VpsFree::Irc::Bot
  class KeepNick
    include Cinch::Plugin

    timer 30, method: :check
  
    def check
      bot.nick = config[:nick] if config[:nick] != bot.nick
    end
  end
end
