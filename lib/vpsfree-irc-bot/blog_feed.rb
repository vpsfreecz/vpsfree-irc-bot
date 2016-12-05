require 'nokogiri'
require 'open-uri'
require 'time'

module VpsFree::Irc::Bot
  class BlogFeed
    include Cinch::Plugin
    include Helpers

    timer 120, method: :check, threaded: false

    def check
      @url ||= URI(config[:url])
      @since ||= Time.now

      doc = Nokogiri::XML(@url.open)
      articles = []

      doc.xpath('//item').each do |item|
        t = Time.rfc822(item.xpath('pubDate').text)
        break if t < @since

        articles << {
            date: t,
            title: item.xpath('title').text,
            link: item.xpath('link').text,
            author: item.xpath('dc:creator').text,
        }
      end

      articles.reverse_each do |a|
        bot.channels.each do |channel|
          log_mutable_send(
              channel,
              "[blog] #{a[:title]} by #{a[:author]}\n"+
              "[blog] #{a[:link]}"
          )
        end
      end

      @since = Time.now if articles.any?
      
    rescue => e
      exception(e)
    end
  end
end
