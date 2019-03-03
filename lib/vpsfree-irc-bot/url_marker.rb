require 'open-uri'
require 'nokogiri'

module VpsFree::Irc::Bot
  class UrlMarker
    class FetchError < StandardError ; end

    include Cinch::Plugin
    include Helpers
    
    listen_to :channel, method: :channel

    def channel(m)
      return if /^\s*(http(s?):\/\/[^\s]+)\s*$/ !~ m.message
    
      response, url = fetch(
        $1,
        max_redirects: config[:max_redirects] || 5,
        max_size: config[:max_size] || 10*1024*1024,
      )
      doc = Nokogiri::HTML(response)
    
      reply(m, "Page title: #{title(doc)}")
      reply(m, "Redirected to: #{url}") if url.strip != $1.strip

    rescue FetchError => e
      reply(m, e.message)

    rescue => e
      exception(e)
    end
    
    protected
    # @param url [String]
    # @param opts [Hash]
    # @option opts [Integer] max_redirects
    # @option opts [Integer] max_size
    def fetch(url, opts)
      if opts[:max_redirects] == 0
        raise FetchError, "More than #{opts[:max_redirects]} HTTP redirects"
      end

      ret = nil

      Net::HTTP.get_response(URI(url)) do |res|
        case res
        when Net::HTTPSuccess
          size = res.content_length
          type = res.content_type

          if size && size > opts[:max_size]
            raise FetchError, "Response is too large (#{unitize(size)})"

          elsif type && !%w(text/html).include?(type)
            if size
              raise FetchError, "Content type '#{type}', size #{unitize(size)}"

            else
              fail "unsupported content type '#{type}'"
            end
          end

          ret = [read_body(res, opts[:max_size]), url]

        when Net::HTTPRedirection
          opts[:max_redirects] -= 1
          ret = fetch(res['location'], opts)
         
        when Net::HTTPNotFound
          raise FetchError, "Link returns HTTP 404 - Not Found"
        
        when Net::HTTPServerError
          raise FetchError, "Link returns HTTP 500 - Server Error"

        else
          fail "unexpected response #{res}"
        end
      end

      ret
    end

    def read_body(res, max_size)
      body = ''

      res.read_body do |segment|
        body << segment
        
        if res.size > max_size
          raise FetchError, "Response is too large (#{unitize(size)})"
        end
      end

      body
    end

    def unitize(n)
      bits = 39
      units = %i(TiB GiB MiB KiB)

      units.each do |u|
        threshold = 2 << bits

        return "#{(n / threshold.to_f).round(2)} #{u}" if n >= threshold

        bits -= 10
      end

      "#{n} bytes"
    end

    def title(doc)
      ret = doc.xpath('(//title)[1]').text.strip[0..255]
      ret.gsub!(/\r\n|\n/, ' ')
      ret
    end
  end
end
