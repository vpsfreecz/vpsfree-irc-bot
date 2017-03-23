require 'thread'

module VpsFree::Irc::Bot
  class Persistence
    def initialize(server)
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
      File.join(Dir.home, '.vpsfree-irc-bot', @server)
    end
  end
end
