require 'thread'

module VpsFree::Irc::Bot
  class UserStorage
    def self.defaults(hash = nil)
      @defaults ||= {}

      if hash
        @defaults.update(hash)

      else
        @defaults
      end
    end

    def self.instance
      return @instance if @instance
      @instance = new
    end

    private
    def initialize
      @mutex = Mutex.new
      @channels = {}
      @changed = {}

      FileUtils.mkpath(save_dir)

      load
      persistence
    end

    public
    # @param channel [Cinch::Channel]
    # @param user [Cinch::User]
    def get(channel, user)
      @mutex.synchronize { yield(do_get(channel.to_s, user.nick)) }
    end

    def get_all(channel)
      @mutex.synchronize { yield(do_get(channel.to_s, nil)) }
    end

    # @param channel [Cinch::Channel]
    # @param user [Cinch::User]
    def set(channel, user)
      @mutex.synchronize do
        data = do_get(channel.to_s, user.nick)
        ret = yield(data)
        do_set(channel.to_s, user.nick, data, ret === true)
        data
      end
    end

    protected
    # @param channel [String]
    # @param user [String]
    def do_get(channel, nick)
      @channels[channel] ||= {}

      if nick.nil?
        @channels[channel]

      else
        @channels[channel][nick] ||= self.class.defaults
      end
    end

    # @param channel [String]
    # @param user [String]
    # @param data [Hash]
    # @param changed [Boolean]
    def do_set(channel, nick, data, changed)
      @channels[channel] ||= {}
      @channels[channel][nick] = data

      @changed[channel] = true if changed

      data
    end

    def load
      return unless Dir.exists?(save_dir)

      Dir.glob(File.join(save_dir, '*.yml')) do |f|
        @channels[ File.basename(f).split('.')[0] ] = YAML.load(File.read(f))
      end
    end

    # @param channel [String]
    def save(channel)
      file = File.join(save_dir, "#{channel}.yml")

      File.open("#{file}.new", 'w') do |f|
        f.write(YAML.dump(@channels[channel]))
      end

      FileUtils.mv("#{file}.new", file)
    end
    
    def persistence
      Thread.new do
        loop do
          sleep(15)

          @mutex.synchronize do
            @changed.delete_if do |chan, changed|
              save(chan) if changed
              true
            end

            save
          end
        end
      end
    end

    def save_dir
      File.join(Dir.home, '.vpsfree-irc-bot', 'channels')
    end
  end
end
