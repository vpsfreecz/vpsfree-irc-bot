require 'cinch'
require 'date'
require 'json'
require 'open-uri'
require 'reverse_markdown'
require 'vpsfree-irc-bot/api'
require 'vpsfree-irc-bot/helpers'

module VpsFree::Irc::Bot
  class WebEventLog
    include Cinch::Plugin
    include Helpers
    include Api

    timer 60, method: :check, threaded: false
    set required_options: %i(channels)

    def check
      unless api_setup?
        warn 'Skipping web event log check, API not set up'
        return
      end

      client do |api|
        @since ||= Time.now

        events = api.news_log.list(since: @since.iso8601)

        events.each do |e|
          bot.channels.each do |channel|
            next unless config[:channels].include?(channel.name)
            log_mutable_send(
              channel,
              "News from vpsAdmin: #{ReverseMarkdown.convert(e.message).strip}",
              :notice
            )
          end
        end

        @since = Time.now if events.any?
      end

    rescue => e
      exception(e)
    end
  end
end
