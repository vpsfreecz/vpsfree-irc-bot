module VpsFree::Irc::Bot
  class Uptime
    include Cinch::Plugin
    include Command
    
    listen_to :connect, method: :connect
    listen_to :message, method: :message

    command :uptime do
      desc "show bot's uptime"
      channel false
    end

    def initialize(*_)
      super
      @started_at = Time.now
      @msgs = 0
    end

    def connect(m)
      @connected_at = Time.now
    end

    def message(m)
      synchronize(:uptime) { @msgs += 1 }
    end

    def cmd_uptime(m, channel)
      synchronize(:uptime) do
        m.reply("Uptime: #{format_duration(Time.now - @started_at)}")
        m.reply("Connected: #{format_duration(Time.now - @connected_at)}")

        cmds = Command::Counter.count
        m.reply("Processed #{@msgs - cmds} messages and #{cmds} commands")
      end
    end

    protected
    def format_duration(interval)
      d = interval / 86400
      h = interval / 3600 % 24
      m = interval / 60 % 60
      s = interval % 60

      if d > 0
        "%d days, %02d:%02d:%02d" % [d, h, m, s]
      else
        "%02d:%02d:%02d" % [h, m, s]
      end
    end
  end
end
