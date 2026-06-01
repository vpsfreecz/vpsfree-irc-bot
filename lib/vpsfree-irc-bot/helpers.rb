module VpsFree::Irc::Bot
  module Helpers
    MessageStub = Struct.new(:time, :channel, :user, :message, :params)

    # @param channel [Cinch::Channel]
    # @param msg [String]
    # @param type [Symbol]
    def log_send(channel, msg, type = :msg, *args)
      lines = msg.to_s.split("\n")

      logger = if is_a?(ChannelLog)
                 self
               else
                 bot.plugins.detect { |p| p.is_a?(ChannelLog) }
               end

      if type == :me
        lines.each { |line| channel.action(line) }
      else
        # matterbridge does not pass IRC notices, so until that is changed,
        # send normal messages.
        lines.each { |line| channel.send(line) }
      end

      t = Time.now
      lines.each do |line|
        logger.log(
          type,
          MessageStub.new(t, channel, bot, line),
          *args
        )
      end
    end

    # Same arguments as for {#log_send}, except it does nothing if the bot
    # is muted.
    def log_mutable_send(*)
      return if State.get.muted?

      log_send(*)
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
