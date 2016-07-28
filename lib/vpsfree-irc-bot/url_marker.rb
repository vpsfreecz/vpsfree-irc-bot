require 'open-uri'
require 'nokogiri'

module VpsFree::Irc::Bot
  class UrlMarker
    include Cinch::Plugin
    
    listen_to :channel, method: :channel

    def channel(m)
      return if /^\s*(http(s?):\/\/[^\s]+)$/ !~ m.message
    
      url = URI.parse($1)
      doc = Nokogiri::HTML(url.open)
      
      m.reply("Page title: #{doc.xpath('//title').text.strip[0..255]} (#{url})")

    rescue
      # skip on error
    end
  end
end
