require 'cgi'

module VpsFree::Irc::Bot
  # Wrapper for channel log file path
  class LogPath
    # @param suffix [String]
    # @param server [String, nil]
    # @param channel [String, nil]
    def initialize(suffix, server: nil, channel: nil)
      @suffix = suffix
      @server = server
      @channel = channel
    end

    # Return a new path object with preconfigured server/channel
    # @param server [String]
    # @param channel [String]
    # @return [LogPath]
    def resolve(server: nil, channel: nil)
      ret = clone
      ret.set(server: server, channel: channel)
      ret
    end

    # Get file system path
    # @param server [String, nil]
    # @param channel [String, nil]
    # @param time [Time]
    def as_local(server: nil, channel: nil, time:)
      server ||= @server
      channel ||= @channel

      if server.nil?
        raise ArgumentError, 'missing server'
      elsif channel.nil?
        raise ArgumentError, 'missing channel'
      end

      File.join(
        server,
        channel,
        time.strftime('%Y/%m/%d') + '.' + @suffix,
      )
    end

    # Get path for URL
    # @param server [String, nil]
    # @param channel [String, nil]
    # @param time [Time]
    def as_url(server: nil, channel: nil, time:)
      server ||= @server
      channel ||= @channel

      if server.nil?
        raise ArgumentError, 'missing server'
      elsif channel.nil?
        raise ArgumentError, 'missing channel'
      end

      File.join(
        CGI.escape(server),
        CGI.escape(channel),
        time.strftime('%Y/%m/%d') + '.' + @suffix,
      )
    end

    # @return [Integer] number of / in path
    def depth
      4
    end

    protected
    def set(server: nil, channel: nil)
      @server = server
      @channel = channel
    end
  end
end
