require 'thread'

module VpsFree::Irc::Bot
  class Persistence
    def initialize(state_dir, server)
      @state_dir = state_dir
      @server = server
      @mutex = Mutex.new

      load
      persistence
    end

    protected
    def do_sync(&block)
      if @mutex.owned?
        block.call

      else
        @mutex.synchronize { block.call }
      end
    end

    def save_dir
      File.join(@state_dir, @server)
    end
  end
end
