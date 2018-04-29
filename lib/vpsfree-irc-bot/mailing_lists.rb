require 'base64'

module VpsFree::Irc::Bot
  class MailingLists
    LISTS = {
        outage: {
            id: '"vpsFree.cz outage list" <outage-list.lists.vpsfree.cz>',
            prefix: '[vpsFree: outage-list]',
        },
        news: {
            id: '<news-list.lists.vpsfree.cz>',
        },
        community: {
            id: '"vpsFree.cz Community list" <community-list.lists.vpsfree.cz>',
        },
    }
    
    include Cinch::Plugin
    include MailMan
    include Helpers

    set required_options: %i(server port username password channels)
    
    mailman do |m|
      m.server = {
            address: config[:server],
            port: config[:port],
            user_name: config[:username],
            password: config[:password],
            enable_ssl: config[:enable_ssl],
      }
      m.archive_dir = config[:archive_dir]

      LISTS.each do |list, opts|
        m.list name: "#{list}-list",
              id: opts[:id],
              prefix: opts[:prefix] || "[vpsFree.cz: #{list}-list]",
              method: list == :outage ? :"#{list}_list" : :report_message
      end
    end

    def outage_list(list, m, url)
      notices = [
          "#{list.prefix} Výpadek / Outage",
          "#{list.prefix} Odstávka / Maintenance",
      ]
      
      return if notices.detect { |s| m.subject.start_with?(s) }
    
      report_message(list, m, url)
    end

    def report_message(list, m, url)
      rx = /^((Re:\s*)*#{Regexp.escape(list.prefix)})/
      
      if rx !~ m.subject
        warn("Stray message: #{m.subject}")
        return
      end

      prefix = $1
      re = !$2.nil?
      sender = m[:from].display_names.first

      send_channels(
          "[#{list.name}] "+
          (re ? 'Re: ' : '')+
          "#{m.subject[prefix.size+1..-1]}"+
          (sender ? " from #{sender}" : '')+
          " (#{url})"
      )
    end

    protected
    def send_channels(msg)
      bot.channels.each do |channel|
        next unless config[:channels].include?(channel.name)
        log_mutable_send(channel, msg)
      end
    end
  end
end
