module VpsFree::Irc::Bot
  class ChannelLog
    include Cinch::Plugin

    listen_to :connect, method: :connect
    listen_to :topic, method: :topic
    listen_to :channel, method: :msg
    listen_to :action, method: :action
    listen_to :join, method: :join
    listen_to :leaving, method: :leave
    listen_to :nick, method: :nick
    match :archive, react_on: :private, use_prefix: false, method: :archive

    def connect(m)
      @loggers = {}
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
      if bot.nick == m.user.nick
        @loggers[m.channel.to_s] = [
            HtmlLogger.new(
                m.channel,
                'html',
                File.join(bot.config.archive_dst, 'html/'),
                '%{server}/%{channel}/%Y/%m/%d.html',
            ),
        ]
      end

      log(:join, m)
    end

    def leave(m, user)
      log(:leave, m, user)
    end

    def nick(m)
      log(:nick, m)
    end

    def archive(m)
      if bot.config.archive_url
        m.reply(bot.config.archive_url)

      else
        m.reply('Web archive URL has not been set.')
      end
    end

    protected
    def log(type, m, *args)
      @loggers[m.channel.to_s].each { |l| l.log(type, m, *args) }
    end
  end
end
