module VpsFree::Irc::Bot
  module Helpers
    MessageStub = Struct.new(:time, :channel, :user, :message, :params)

    # @param channel [Cinch::Channel]
    # @param type [Symbol]
    # @param msg [String]
    def log_send(channel, msg, type = :msg, *args)
      if self.is_a?(ChannelLog)
        logger = self
      else
        logger = bot.plugins.detect { |p| p.is_a?(ChannelLog) }
      end

      channel.send(msg)
      logger.log(
          type,
          MessageStub.new(Time.now, channel, bot, msg),
          *args
      )
    end

    # @param channel [Cinch::Message]
    # @param msg [String]
    def reply(m, msg)
      if m.target.is_a?(Cinch::Channel)
        log_send(m.target, msg)

      else
        m.reply(msg)
      end
    end
  end
end