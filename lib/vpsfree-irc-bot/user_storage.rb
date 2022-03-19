require 'fileutils'
require 'thread'
require 'vpsfree-irc-bot/persistence'

module VpsFree::Irc::Bot
  class UserStorage < Persistence
    def self.defaults(hash = nil)
      @defaults ||= {}

      if hash
        @defaults.update(hash)

      else
        @defaults
      end
    end

    def self.init(state_dir, server)
      @instance = new(state_dir, server)
    end

    def self.instance
      @instance
    end

    private
    def initialize(state_dir, server)
      @channels = {}
      @changed = {}
      super(state_dir, server)
      FileUtils.mkpath(save_dir)
    end

    public
    # @param channel [Cinch::Channel]
    # @param user [Cinch::User]
    def get(channel, user)
      do_sync { yield(do_get(channel.to_s, user.nick)) }
    end

    def get_channel(channel)
      do_sync { yield(do_get(channel.to_s, nil)) }
    end

    # @param channel [Cinch::Channel]
    # @param user [Cinch::User]
    def set(channel, user)
      do_sync do
        data = do_get(channel.to_s, user.nick)
        ret = yield(data)
        do_set(channel.to_s, user.nick, data, ret === true)
        data
      end
    end

    def set_all
      do_sync do
        ret = yield(@channels)

        if ret === true
          @channels.each_key do |chan|
            @changed[chan] = true
          end
        end

        @channels
      end
    end

    def synchronize
      do_sync { yield(self) }
    end

    protected
    # @param channel [String]
    # @param user [String]
    def do_get(channel, nick)
      @channels[channel] ||= {}

      if nick.nil?
        @channels[channel]

      else
        data = Marshal.load(Marshal.dump(self.class.defaults))
        data.update(@channels[channel][nick]) if @channels[channel][nick]
        data
      end
    end

    # @param channel [String]
    # @param user [String]
    # @param data [Hash]
    # @param changed [Boolean]
    def do_set(channel, nick, data, changed)
      @channels[channel] ||= {}

      if nick.nil?
        @channels[channel] = data

      else
        @channels[channel][nick] = data
      end

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

          do_sync do
            @changed.delete_if do |chan, changed|
              save(chan) if changed
              true
            end
          end
        end
      end
    end

    def save_dir
      File.join(super, 'channels')
    end
  end
end
