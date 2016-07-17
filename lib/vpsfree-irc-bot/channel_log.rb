module VpsFree::Irc::Bot
  class ChannelLog
    include Cinch::Plugin
    include Command

    HTML_PATH = '%{server}/%{channel}/%Y/%m/%d.html'

    listen_to :connect, method: :connect
    listen_to :topic, method: :topic
    listen_to :channel, method: :msg
    listen_to :action, method: :action
    listen_to :join, method: :join
    listen_to :leaving, method: :leave
    listen_to :nick, method: :nick

    command :archive do
      desc 'get URL to the web archive'
      arg :which, required: false
    end

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
                HTML_PATH, 
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

    def cmd_archive(m, channel, which = nil)
      unless bot.config.archive_url
        m.reply('Web archive URL has not been set.')
        return
      end

      case which
      when nil
        m.reply(File.join(
            bot.config.archive_url,
            bot.config.server,
            channel.to_s,
        ))
      when 'today'
        m.reply(File.join(
            bot.config.archive_url,
            Time.now.strftime(HTML_PATH) % {
                server: bot.config.server,
                channel: channel.to_s,
            }
        ))
      
      else
        m.reply("'which' must be empty or 'today'")
      end
    end

    protected
    def log(type, m, *args)
      @loggers[m.channel.to_s].each { |l| l.log(type, m, *args) }
    end
  end
end
