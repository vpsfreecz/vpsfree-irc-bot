require 'cinch'
require 'thread'
require 'vpsfree-irc-bot/helpers'

module VpsFree::Irc::Bot
  class DiscourseWebHook::Announcer
    include Cinch::Plugin
    include Helpers

    set required_options: %i(channels)
    timer 1, method: :check, threaded: false

    class << self
      # @param event [DiscourseWebHook::Event]
      def announce(event)
        queue << event
      end

      # @return [DiscourseWebHook::Event]
      def get_event
        queue.pop
      end

      def queue
        @queue ||= ::Queue.new
      end
    end

    def check
      event = self.class.get_event

      bot.channels.each do |channel|
        next unless config[:channels].include?(channel.name)

        log_mutable_send(
          channel,
          event.to_s,
          :notice
        )
      end
    end
  end
end
