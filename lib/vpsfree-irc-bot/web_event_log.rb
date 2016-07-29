require 'json'
require 'open-uri'
require 'reverse_markdown'
require 'thread'

module VpsFree::Irc::Bot
  class WebEventLog
    include Cinch::Plugin

    def initialize(*_)
      super

      @url = URI.join(bot.config.webui_url, 'event_log.php')
      @since = Time.now.to_i

      Thread.new do
        loop do
          sleep(60)
          check
        end
      end
    end

    def check
      @url.query = "since=#{@since.to_i}"

      events = JSON.parse(@url.read, symbolize_names: true)

      events.each do |e|
        bot.channels.each do |channel|
          channel.send(
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
