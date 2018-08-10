module VpsFree::Irc::Bot
  class KeepChannels
    include Cinch::Plugin

    timer 60, method: :check
  
    def check
      config[:channels].each do |name|
        bot.join(name) unless bot.channels.detect { |c| c.to_s == name }
      end
    end
  end
end
