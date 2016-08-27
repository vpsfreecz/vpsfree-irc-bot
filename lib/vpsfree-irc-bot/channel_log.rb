require 'thread'
require 'uri'

module VpsFree::Irc::Bot
  class ChannelLog
    include Cinch::Plugin
    include Command
    include Helpers

    HTML_PATH = '%{server}/%{channel}/%Y/%m/%d.html'
    YAML_PATH = '%{server}/%{channel}/%Y/%m/%d.yml'

    set required_options: %i(archive_dst)

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

    def initialize(*_)
      super
      @users_mutex = Mutex.new

      DayChange.on do |yesterday|
        next unless @loggers

        @loggers.each do |chan_name, loggers|
          loggers.each { |l| l.next_day }
 
          if config[:archive_url] \
             && c = bot.channels.detect { |chan| chan.to_s == chan_name }
            log_send(
                c,
                "Yesterday's log can be found at #{html_day_log_uri(chan_name, yesterday)}"
            )
          end
        end
      end
    end

    def connect(m)
      @loggers = {}
      @users = {}
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
        # Remember all users connected to this channel
        channel_users do |users|
          m.channel.users.each_key do |u|
            users[u.nick] ||= []
            users[u.nick] << m.channel.to_s
          end
        end

        @loggers[m.channel.to_s] = [
            HtmlLogger.new(
                m.channel,
                'html',
                File.join(config[:archive_dst], 'html/'),
                HTML_PATH, 
            ),
            TemplateLogger.new(
                m.channel,
                'yml',
                File.join(config[:archive_dst], 'yml/'),
                YAML_PATH,
            ),
        ]

      else
        # New user joined this channel
        channel_users do |users|
          users[m.user.nick] ||= []
          users[m.user.nick] << m.channel.to_s
        end
      end

      log(:join, m)
    end

    def leave(m, user)
      if m.channel.nil?
        # The user has disconnected from the server.
        # Log it as if he has left all monitored channels.
        channel_users do |users|
          if users.has_key?(user.nick)
            users[user.nick].each do |chan|
              @loggers[chan].each { |l| l.log(:leave, m, user) }
            end

            users.delete(user.nick)
          end
        end

      else
        # The user has left one concrete channel
        channel_users { |users| users[user.nick].delete(m.channel.to_s) }

        log(:leave, m, user)
      end
    end

    # Log nick change in all channels the user is in
    def nick(m)
      channel_users do |users|
        unless users.has_key?(m.user.last_nick)
          fail "user '#{m.user.last_nick}' not found"
        end
        
        users[m.user.nick] = users[m.user.last_nick]
        users.delete(m.user.last_nick)

        users[m.user.nick].each do |chan|
          @loggers[chan].each { |l| l.log(:nick, m) }
        end
      end
    end

    def cmd_archive(m, channel, which = nil)
      unless config[:archive_url]
        reply(m, 'Web archive URL has not been set.')
        return
      end

      case which
      when nil
        uri = URI.encode(
                File.join(
                config[:archive_url],
                bot.config.server,
                channel.to_s,
            )
        )
      when 'today'
        uri = html_day_log_uri(channel.to_s, Time.now)
      
      else
        reply(m, "'which' must be empty or 'today'")
        return
      end

      reply(m, uri)
    end

    def log(type, m, *args)
      @loggers[m.channel.to_s].each { |l| l.log(type, m, *args) }
    end

    protected
    def channel_users
      @users_mutex.synchronize { yield(@users) }
    end

    # @param channel [String]
    # @param t [Time]
    def html_day_log_uri(channel, t)
      URI.encode(
          File.join(
              config[:archive_url],
              t.strftime(HTML_PATH) % {
                  server: bot.config.server,
                  channel: channel,
              }
          )
      )
    end
  end
end
