module VpsFree::Irc::Bot
  class ChannelLog
    include Cinch::Plugin

    listen_to :topic, method: :topic
    listen_to :channel, method: :msg
    listen_to :action, method: :action
    listen_to :join, method: :join
    listen_to :leaving, method: :leave
    match :archive, method: :archive

    def initialize(*args)
      super

      @loggers = [
          HtmlLogger.new('html', 'html/', '%Y/%m/%d.html'),
          #Loggers::Template.new('yml', 'yml/', '%Y/%m/%d.yml'),
      ]
    end

    def topic(m)
      log(:topic, m)
    end

    def msg(m)
      if m.command == 'PRIVMSG' && m.params[1] && m.params[1].include?("\u0001ACTION")
        # ignore /me
        return
      end
      log(:msg, m)
    end

    def action(m)
      log(:me, m)
    end

    def join(m)
      log(:join, m)
    end

    def leave(m, user)
      log(:leave, m, user)
    end

    def archive(m)
      m.reply('http://im.vpsfree.cz/whatnot')
    end

    protected
    def log(type, *args)
      @loggers.each { |l| l.log(type, *args) }
    end
  end
end
