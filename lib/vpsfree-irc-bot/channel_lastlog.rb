require 'thread'

module VpsFree::Irc::Bot
  class ChannelLastLog
    include Cinch::Plugin
    include Command

    SIZE = 100
    
    listen_to :connect, method: :connect
    listen_to :join, method: :join
    listen_to :action, method: :action
    listen_to :channel, method: :msg

    command :lastlog do
      desc 'print N last messages, defaults to 20'
      arg :n, required: false
    end

    def initialize(*args)
      super
      @mutex = Mutex.new
    end

    def connect(m)
      @buffers = {}
    end

    def join(m)
      return if bot.nick != m.user.nick
      
      @buffers[m.channel.to_s] = []
    end

    def msg(m)
      if m.command == 'PRIVMSG' && m.params[1] && m.params[1].include?("\u0001ACTION")
        # ignore /me
        return
      end
      
      log(m)
    end

    def action(m)
      log(m, status: true, message: m.message['ACTION'.size + 2..-2])
    end

    def cmd_lastlog(m, channel, raw_n = nil)
      n = raw_n ? raw_n.to_i : 20

      @mutex.synchronize do
        buf = @buffers[channel.to_s]
        from = buf.size >= n ? buf.size - n : 0
        slice = buf[from .. buf.size]

        if slice.any?
          m.user.send("Last #{slice.size} messages from '#{channel}':")

        else
          m.user.send("There are no messages from '#{channel}' in the log.")
        end

        slice.each do |msg|
          s = "[#{msg[:time].strftime('%Y-%m-%d %H:%M:%S')}] "

          if msg[:status]
            s += " * #{msg[:nick]} #{msg[:message]}"

          else
            s += "< #{msg[:nick]}> #{msg[:message]}"
          end

          m.user.send(s)
        end
      end 
    end

    protected
    def log(m, opts = {})
      @mutex.synchronize do
        hash = {
            time: m.time,
            nick: m.user.nick,
            message: m.message,
        }
        hash.update(opts)

        buf = @buffers[m.channel.to_s]

        buf << hash
        buf.delete_at(0) if buf.size > SIZE
      end
    end
  end
end
