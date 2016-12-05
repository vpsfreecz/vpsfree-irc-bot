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
      sync { get_muted_until ? true : false }
    end

    def muted_until
      sync do
        muted = get_muted_until
        muted && muted.clone
      end
    end

    protected
    def sync
      @mutex.synchronize { yield }
    end

    def get_muted_until
      if @muted_until
        @muted_until = nil if (@muted_until) < Time.now
      end

      @muted_until
    end
  end
end
