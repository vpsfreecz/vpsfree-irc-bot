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

      if type == :me
        channel.action(msg)

      else
        channel.send(msg)
      end

      t = Time.now
      msg.split("\n").each do |line|
        logger.log(
          type,
          MessageStub.new(t, channel, bot, line),
          *args
        )
      end
    end

    # Same arguments as for {#log_send}, except it does nothing if the bot
    # is muted.
    def log_mutable_send(*args)
      return if State.get.muted?

      log_send(*args)
    end

    # @param m [Cinch::Message]
    # @param msg [String]
    def reply(m, msg)
      if m.target.is_a?(Cinch::Channel)
        log_send(m.target, msg)

      else
        m.reply(msg)
      end
    end

    # @param m [Cinch::Message]
    # @param msg [String]
    def reply_action(m, msg)
      if m.target.is_a?(Cinch::Channel)
        log_send(m.target, msg, :me)

      else
        m.target.action(msg)
      end
    end
  end
end
