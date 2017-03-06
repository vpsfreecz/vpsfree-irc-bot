require 'date'

module VpsFree::Irc::Bot
  class OutageReports
    include Cinch::Plugin
    include Helpers
    include Api

    timer 10, method: :check, threaded: false

    def check
      @outages ||= {}
      @since ||= Time.now

      client do |api|
        @webui ||= api.system_config.show('webui', 'base_url').value

        api.outage.list(active: true, since: @since).each do |outage|
          report_outage(outage)
        end

        api.outage_update.list(since: @since).each do |update|
          report_update(update)
        end

        @since = Time.now
      end
        
    rescue => e
      exception(e)
    end

    protected
    def report_outage(outage)
      send_channels(<<-END
New #{outage.planned ? 'planned' : 'unplanned'} outage ##{outage.id} reported at #{fmt_date(outage.begins_at)}
     Systems: #{outage.entity.list.map { |v| v.label }.join(', ')}
 Outage type: #{outage.type}
    Duration: #{outage.duration} minutes
      Reason: #{outage.en_summary}
  Handled by: #{outage.handler.list.map { |v| v.full_name }.join(', ')}
#{outage_url(outage.id)}
          END
      )
    
    rescue => e
      exception(e)
    end

    def report_update(update)
      return if update.state == 'announced'

      attrs = %i(begins_at finished_at state type duration)
      changes = []
      
      attrs.each do |attr|
        v = update.send(attr)
        next unless v

        case attr
        when :begins_at
          changes << "  Begins at: moved to #{fmt_date(v)}"

        when :finished_at
          changes << "Finished at: #{fmt_date(v)}"

        when :duration
          changes << "   Duration: #{v} minutes"

        when :state
          changes << "      State: #{v}"

        when :type
          changes << "Outage type: #{v}"
        end
      end

      send_channels("Update of outage ##{update.outage_id} at #{fmt_date(update.created_at)}")
      changes.each { |v| send_channels(v) }
      
      if update.en_summary && !update.en_summary.empty?
        send_channels("Summary: #{update.en_summary}")
      end

      send_channels("Reported by: #{update.reporter_name}") if update.reporter_name
      send_channels(outage_url(update.outage_id))
    end

    def fmt_date(v)
      DateTime.iso8601(v).to_time.localtime.strftime('%Y-%m-%d %H:%M %Z')
    end

    def outage_url(id)
      File.join(@webui, "?page=outage&action=show&id=#{id}")
    end
    
    def send_channels(msg)
      bot.channels.each { |c| log_mutable_send(c, msg) }
    end
  end
end
