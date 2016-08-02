require 'base64'
require 'mail'
require 'thread'

module VpsFree::Irc::Bot
  class OutageReport
    include Cinch::Plugin
    include Helpers

    SUBJECT_PREFIX = '[vpsFree: outage-list]'

    def initialize(*_)
      super
      return if bot.config.outage_mail.nil?

      this = self

      ::Mail.defaults do
        retriever_method(
            :pop3,
            address: this.bot.config.outage_mail[:server],
            port: this.bot.config.outage_mail[:port],
            user_name: this.bot.config.outage_mail[:username],
            password: this.bot.config.outage_mail[:password],
            enable_ssl: this.bot.config.outage_mail[:enable_ssl],
        )
      end

      Thread.new do
        loop do
          sleep(60)
          check
        end
      end
    end

    def check
      Mail.find_and_delete.each do |m|
        notices = [
            "#{SUBJECT_PREFIX} Neplanovany vypadek / Unplanned outage",
            "#{SUBJECT_PREFIX} Planovany vypadek / Planned outage",
        ]
        
        if notices.detect { |s| m.subject.start_with?(s) }
          outage_notice(m)

        else
          outage_message(m)
        end
      end
      
    rescue => e
      exception(e)
    end

    # Notice is an automated message with defined format.
    def outage_notice(m)
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
          "#{m['List-Archive']}"
      )
    end

    # Custom outage message.
    def outage_message(m)
      rx = /^((Re:\s*)*#{Regexp.escape(SUBJECT_PREFIX)})/
      
      if rx !~ m.subject
        warn("Stray message: #{m.subject}")
        return
      end

      prefix = $1
      re = !$2.nil?

      send_channels(
          "New message in outage list: "+
          (re ? 'Re: ' : '')+
          "#{m.subject[prefix.size+1..-1]} (#{m['List-Archive']})"
      )
    end

    def send_channels(msg)
      bot.channels.each { |c| log_send(c, msg) }
    end
  end
end
