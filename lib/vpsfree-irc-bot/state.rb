require 'thread'

module VpsFree::Irc::Bot
  # Singleton class for holding the bot's state
  class State
    @@instance = nil

    def self.get
      @@instance = new unless @@instance
      @@instance
    end

    private
    def initialize
      @mutex = Mutex.new
    end

    public
    # @param n [Integer] duration in seconds
    def mute(until_time)
      sync { @muted_until = until_time }
    end

    def unmute
      sync { @muted_until = nil }
    end

    def muted?
      sync do
        if @muted_until
          @muted_until = nil if (@muted_until) < Time.now
        end

        @muted_until ? true : false
      end
    end

    def muted_until
      sync { @muted_until && @muted_until.clone }
    end

    protected
    def sync
      @mutex.synchronize { yield }
    end
  end
end
