require 'nokogiri'
require 'xmlrpc/client'
require 'uri'

module VpsFree::Irc::Bot
  class DokuWiki
    include Cinch::Plugin

    INTERVAL = 120

    set required_options: %i(wikis)
    timer INTERVAL, method: :check, threaded: false

    def initialize(*args)
      super

      @wikis = config[:wikis].map { |opts| Wiki.new(bot, opts) }
    end

    def check
      @wikis.each do |w|
        begin
          w.check

        rescue => e
          exception(e)
        end
      end
    end

    class Wiki
      include Helpers

      attr_reader :bot, :config

      def initialize(bot, opts)
        @bot = bot
        @config = opts
      end

      def check
        @url ||= URI(File.join(config[:url], 'lib/exe/xmlrpc.php'))
        @since ||= Time.now.to_i - INTERVAL
        @server = XMLRPC::Client.new_from_uri(@url)

        ret = @server.call('wiki.getRecentChanges', @since)
        ret.each { |change| handle_change(change) } unless State.get.muted?

        @since = Time.now.to_i unless ret.empty?

      rescue XMLRPC::FaultException => e
        return if e.faultCode == 321  # No changes
        error("RPC failed: #{e.faultCode} - #{e.faultString}")
      end

      def handle_change(change)
        revs = @server.call('wiki.getPageVersions', change['name'])
        cur_i = revs.index { |rev| rev['version'] == change['version'] }

        unless cur_i
          error(
            "Version '#{change['version']}' of '#{change['name']}' "+
            "not found in page versions"
          )
          return
        end

        cur = revs[cur_i]

        case cur['type'].upcase
        when 'C'  # page created
          send_channels(
            "Page #{change['name']} created by #{change['author']} "+
            "(#{page_url(change['name'])})"
          )

        when 'E'  # page changed
          prev = revs[cur_i + 1]

          send_channels(
            "Page #{change['name']} changed by #{change['author']} "+
            "(#{page_url(change['name'])})"
          )
          
          if prev
            send_channels("Summary: #{cur['sum']}") if cur['sum'] && !cur['sum'].strip.empty?
            send_channels("Diff: #{diff_url(change['name'], prev, cur)}")
          end

          notify_maintainers(change['name'])

        when 'D'  # deleted
          send_channels(
            "Page #{change['name']} deleted by #{change['author']} "+
            "(#{page_url(change['name'])})"
          )

        else
          error("Unknown revision type '#{cur['type']}'")
          return
        end

      rescue XMLRPC::FaultException => e
        error("RPC failed: #{e.faultCode} - #{e.faultString}")
        send_channels(
          "Page #{change['name']} changed by #{change['author']} "+
          "(#{page_url(change['name'])})"
        )
      end

      def page_url(page)
        url = [config[:url]]
        page = page.gsub(/:/, '/') if config[:namespace_slash]

        case config[:rewrite]
        when nil, 0  # no rewrite
          url << "doku.php?id=#{page}"

        when 1  # rewrite using .htaccess
          url << page

        when 2  # dokuwiki internal rewrite
          url << 'doku.php' << page
        end

        File.join(*url)
      end

      def diff_url(page, rev1, rev2)
        url = page_url(page)
        
        case config[:rewrite]
        when nil, 0  # no rewrite
          url << '&'

        when 1, 2  # rewrite using .htaccess or internal
          url << '?'
        end

        url << "do=diff" \
            << "&rev2[0]=#{rev1['version']}" \
            << "&rev2[1]=#{rev2['version']}" \
            << "&difftype=sidebyside"
        
        url
      end

      def notify_maintainers(page)
        maintainers = fetch_maintainers(page).map { |m| m[:irc] }.select do |v|
          !v.nil? && !v.empty?
        end

        return if maintainers.empty?

        send_channels("Maintainers: #{maintainers.join(', ')}")
      end

      def fetch_maintainers(page)
        html = @server.call('wiki.getPageHTML', page)
        doc = Nokogiri::HTML(html)
        ret = []
        
        doc.xpath("//ul[contains(@class,'maintainers')]/li/a").each do |link|
          m = {nick: link.text.strip}
          
          if link['data-page-exists'] === '1'
            m.update(fetch_maintainer(link['data-page-id']))
          end

          ret << m
        end

        ret
      
      rescue XMLRPC::FaultException => e
        error("RPC failed: #{e.faultCode} - #{e.faultString}")
      end

      def fetch_maintainer(m_page)
        html = @server.call('wiki.getPageHTML', m_page)
        doc = Nokogiri::HTML(html)

        {
          irc: doc.xpath("//div[@class='maintainer']//tr[@class='irc']/td").text.strip,
        }
      
      rescue XMLRPC::FaultException => e
        error("RPC failed: #{e.faultCode} - #{e.faultString}")
      end

      def send_channels(msg)
        bot.channels.each do |channel|
          next unless config[:channels].include?(channel.name)
          log_mutable_send(channel, (config[:prefix] || '[DokuWiki]')+' '+msg)
        end
      end
    end
  end
end
