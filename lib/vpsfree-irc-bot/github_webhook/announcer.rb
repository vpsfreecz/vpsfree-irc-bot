require 'cinch'
require 'thread'
require 'vpsfree-irc-bot/helpers'

module VpsFree::Irc::Bot
  class GitHubWebHook::Announcer
    include Cinch::Plugin
    include Helpers
    
    set required_options: %i(channels)
    timer 1, method: :check, threaded: false

    class << self
      # @param event [GitHubWebHook::Event]
      def announce(event)
        queue << event
      end

      # @return [GitHubWebHook::Event]
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
        if !config[:channels].has_key?(channel.name) \
           || !config[:channels][channel.name].include?(event.repository.full_name)
          next
        end

        log_mutable_send(
          channel,
          MultiLine.new(event.to_s),
          :notice
        )

        p event
      end
    end
  end
end
