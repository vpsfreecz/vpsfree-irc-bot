require 'date'
require 'thread'

module VpsFree::Irc::Bot
  class DayChange
    class << self
      def on(&block)
        @instance.on(&block)
      end

      def start
        @instance = new
        @instance.start
      end
    end

    def initialize
      @mutex = Mutex.new
      @hooks = []
    end

    def on(&block)
      @mutex.synchronize { @hooks << block }
    end

    def start
      Thread.new do
        loop do
          t1 = Time.now
          sleep((t1.to_date.next_day.to_time.to_i - t1.to_i) + 5)
          t2 = Time.now
          
          @mutex.synchronize do
            @hooks.each do |hook|
              hook.call(t1, t2)
            end
          end
        end
      end
    end
  end
end
