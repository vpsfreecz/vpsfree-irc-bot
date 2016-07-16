require 'thread'

module VpsFree::Irc::Bot
  class ChannelLastLog
    include Cinch::Plugin
    
    listen_to :channel, method: :msg
    match /lastlog[\s+\d+]?/, react_on: :private, use_prefix: false, method: :lastlog

    def initialize(*args)
      super
      @buffer = []
      @mutex = Mutex.new
    end

    def msg(m)
      @mutex.synchronize do
        @buffer << {
          time: m.time,
          nick: m.user.nick,
          message: m.message,
        }

        @buffer.delete_at(0) if @buffer.size > 100
      end
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
          m.reply(
              "[#{msg[:time].strftime('%Y-%m-%d %H:%M:%S')}] " +
              "< #{msg[:nick]}> #{msg[:message]}"
          )
        end
      end 
    end
  end
end
