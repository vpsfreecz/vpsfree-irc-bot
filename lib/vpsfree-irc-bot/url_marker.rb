require 'open-uri'
require 'nokogiri'

module VpsFree::Irc::Bot
  class UrlMarker
    include Cinch::Plugin
    include Helpers
    
    listen_to :channel, method: :channel

    def channel(m)
      return if /^\s*(http(s?):\/\/[^\s]+)\s*$/ !~ m.message
    
      url = URI.parse($1)
      doc = Nokogiri::HTML(url.open)
      
      reply(m, "Page title: #{doc.xpath('//title').text.strip[0..255]} (#{url})")

    rescue => e
      exception(e)
    end
  end
end
