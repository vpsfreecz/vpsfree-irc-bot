require 'json'
require 'open-uri'
require 'reverse_markdown'

module VpsFree::Irc::Bot
  class WebEventLog
    include Cinch::Plugin
    include Helpers

    set required_options: %i(webui_url)
    timer 60, method: :check, threaded: false

    def check
      @url ||= URI.join(config[:webui_url], 'event_log.php')
      @since ||= Time.now.to_i

      @url.query = "since=#{@since.to_i}"

      events = JSON.parse(@url.read, symbolize_names: true)

      events.each do |e|
        bot.channels.each do |channel|
          log_mutable_send(
              channel,
              "News from vpsAdmin: "+
              "[#{Time.at(e[:timestamp]).strftime('%Y-%m-%d %H:%M')}] "+
              ReverseMarkdown.convert(e[:message]).strip
          )
        end
      end

      @since = Time.now.to_i if events.any?
      
    rescue => e
      exception(e)
    end
  end
end
