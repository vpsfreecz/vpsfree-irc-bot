require 'xmlrpc/client'
require 'uri'

module VpsFree::Irc::Bot
  class DokuWiki
    include Cinch::Plugin
    include Helpers

    INTERVAL = 120

    set required_options: %i(url)
    timer INTERVAL, method: :check, threaded: false

    def check
      @url ||= URI(File.join(config[:url], 'lib/exe/xmlrpc.php'))
      @since ||= Time.now.to_i - INTERVAL
      @server = XMLRPC::Client.new_from_uri(@url)

      ret = @server.call('wiki.getRecentChanges', @since)
      ret.each { |change| handle_change(change) }

      @since = Time.now.to_i unless ret.empty?

    rescue XMLRPC::FaultException => e
      return if e.faultCode == 321  # No changes
      error("RPC failed: #{e.faultCode} - #{e.faultString}")
    end

    protected
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

      case cur['type']
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

    def send_channels(msg)
      bot.channels.each do |channel|
        log_send(channel, (config[:prefix] || '[DokuWiki]')+' '+msg)
      end
    end
  end
end
