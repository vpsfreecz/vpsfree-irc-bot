require 'base64'

module VpsFree::Irc::Bot
  class MailingLists
    OUTAGE_PREFIX = '[vpsFree: outage-list]'
    
    include Cinch::Plugin
    include MailMan
    include Helpers

    set required_options: %i(server port username password)
    
    mailman do |m|
      m.server = {
            address: config[:server],
            port: config[:port],
            user_name: config[:username],
            password: config[:password],
            enable_ssl: config[:enable_ssl],
      }
      m.archive_dir = config[:archive_dir]

      %i(outage news community).each do |list|
        m.list name: "#{list}-list",
              id: "\"vpsFree.cz #{list} list\" <#{list}-list.lists.vpsfree.cz>",
              prefix: "[vpsFree: #{list}-list]",
              method: list == :outage ? :"#{list}_list" : :report_message
      end
    end

    def outage_list(list, m, url)
      notices = [
          "#{list.prefix} Neplanovany vypadek / Unplanned outage",
          "#{list.prefix} Planovany vypadek / Planned outage",
      ]
      
      if notices.detect { |s| m.subject.start_with?(s) }
        outage_notice(m, url)

      else
        report_message(list, m, url)
      end
    end

    def report_message(list, m, url)
      rx = /^((Re:\s*)*#{Regexp.escape(list.prefix)})/
      
      if rx !~ m.subject
        warn("Stray message: #{m.subject}")
        return
      end

      prefix = $1
      re = !$2.nil?

      send_channels(
          "[#{list.name}] "+
          (re ? 'Re: ' : '')+
          "#{m.subject[prefix.size+1..-1]} (#{url})"
      )
    end

    protected
    # Notice is an automated message with defined format.
    def outage_notice(m, url)
      start = '-----BEGIN BASE64 ENCODED PARSEABLE JSON-----'
      ending = '-----END BASE64 ENCODED PARSEABLE JSON-----'

      body = m.body.decoded
      msg = body[ body.index(start)+start.size .. body.index(ending)-1 ].strip
      data = JSON.parse(Base64.decode64(msg), symbolize_names: true)

      send_channels(
          "New #{data[:type_en].downcase} outage reported at #{data[:date]}\n"+
          "        Nodes: #{data[:servers].join(', ')}\n"+
          "     Duration: #{data[:duration]} minutes\n"+
          "       Reason: #{data[:reason_cs]}\n"+
          " Performed by: #{data[:performed_by]}\n"+
          "#{url}"
      )
    end
    
    def send_channels(msg)
      bot.channels.each { |c| log_send(c, msg) }
    end
  end
end
