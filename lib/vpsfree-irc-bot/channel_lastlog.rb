require 'thread'

module VpsFree::Irc::Bot
  class ChannelLastLog
    include Cinch::Plugin

    SIZE = 100
    
    listen_to :action, method: :action
    listen_to :channel, method: :msg
    match /lastlog[\s+\d+]?/, react_on: :private, use_prefix: false, method: :lastlog

    def initialize(*args)
      super
      @buffer = []
      @mutex = Mutex.new
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

    def lastlog(m)
      params = m.params[1].split
      n = params[1] ? params[1].to_i : 20

      @mutex.synchronize do
        from = @buffer.size >= n ? @buffer.size - n : 0
        slice = @buffer[from .. @buffer.size]

        if slice.any?
          m.reply("Last #{slice.size} messages:")

        else
          m.reply("There are no messages in the log.")
        end

        slice.each do |msg|
          s = "[#{msg[:time].strftime('%Y-%m-%d %H:%M:%S')}] "

          if msg[:status]
            s += " * #{msg[:nick]} #{msg[:message]}"

          else
            s += "< #{msg[:nick]}> #{msg[:message]}"
          end

          m.reply(s)
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

        @buffer << hash
        @buffer.delete_at(0) if @buffer.size > SIZE
      end
    end
  end
end
