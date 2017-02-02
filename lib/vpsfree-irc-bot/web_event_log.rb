require 'date'
require 'json'
require 'open-uri'
require 'reverse_markdown'

module VpsFree::Irc::Bot
  class WebEventLog
    include Cinch::Plugin
    include Helpers
    include Api

    timer 60, method: :check, threaded: false

    def check
      client do |api|
        @since ||= Time.now

        events = api.news_log.list(since: @since.iso8601)

        events.each do |e|
          bot.channels.each do |channel|
            log_mutable_send(
                channel,
                "News from vpsAdmin: "+
                "[#{DateTime.iso8601(e.published_at).to_time.strftime('%Y-%m-%d %H:%M')}] "+
                ReverseMarkdown.convert(e.message).strip
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
