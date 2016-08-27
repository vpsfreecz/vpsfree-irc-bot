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
      server = XMLRPC::Client.new_from_uri(@url)

      ret = server.call('wiki.getRecentChanges', @since)

      ret.each do |change|
        bot.channels.each do |channel|
          log_send(
              channel,
              (config[:prefix] || '[DokuWiki]')+
              " Page #{change['name']} changed by #{change['author']} "+
              "(#{kb_url(change['name'])})"
          )
        end
      end

      @since = Time.now.to_i unless ret.empty?

    rescue XMLRPC::FaultException => e
      return if e.faultCode == 321  # No changes
      error("RPC failed: #{e.faultCode} - #{e.faultString}")
    end

    protected
    def kb_url(page)
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
  end
end
