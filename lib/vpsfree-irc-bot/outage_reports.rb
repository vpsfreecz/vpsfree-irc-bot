require 'date'

module VpsFree::Irc::Bot
  class OutageReports
    include Cinch::Plugin
    include Helpers
    include Api

    REMINDERS = [
        [1*60, 'a minute'],
        [10*60, '10 minutes'],
        [1*60*60, 'an hour'],
        [6*60*60, 'six hours'],
    ]

    timer 10, method: :check, threaded: false
    timer 30, method: :remind, threaded: false

    def check
      @store ||= FileStorage.new(bot.config.server, :outages)
      @since ||= Time.now

      client do |api|
        @webui ||= api.system_config.show('webui', 'base_url').value

        api.outage.list(state: :announced, since: @since - 3600).each do |outage|
          next if @store[outage.id]

          @store[outage.id] = outage_to_hash(outage)
          report_outage(outage)
        end

        api.outage_update.list(since: @since, meta: {includes: 'outage'}).each do |update|
          report_update(update)
        end

        @since = Time.now
      end
        
    rescue => e
      exception(e)
    end

    def remind
      now = Time.now.to_i

      @store.each do |id, outage|
        REMINDERS.each do |t, msg|
          delta = outage[:begins_at] - now

          next if delta > t
          break if outage[:reminded] == t || (t - delta) > 60
        
          send_channels("Outage ##{id} begins in #{msg} (#{fmt_date(outage[:begins_at])})")
          outage[:reminded] = t
          break
        end
      end
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
     
      if update.outage.state == 'announced'
        @store[update.outage_id] = outage_to_hash(update.outage)

      else
        @store.delete(update.outage_id)
      end

      send_channels("Update of outage ##{update.outage_id} at #{fmt_date(update.created_at)}")
      changes.each { |v| send_channels(v) }
      
      if update.en_summary && !update.en_summary.empty?
        send_channels("Summary: #{update.en_summary}")
      end

      send_channels("Reported by: #{update.reporter_name}") if update.reporter_name
      send_channels(outage_url(update.outage_id))
    end

    def get_date(v)
      DateTime.iso8601(v).to_time.localtime
    end

    def fmt_date(v)
      (v.is_a?(Integer) ? Time.at(v) : get_date(v)).strftime('%Y-%m-%d %H:%M %Z')
    end

    def outage_url(id)
      File.join(@webui, "?page=outage&action=show&id=#{id}")
    end
    
    def send_channels(msg)
      bot.channels.each { |c| log_mutable_send(c, msg) }
    end

    def outage_to_hash(outage)
      {
          planned: outage.planned,
          begins_at: get_date(outage.begins_at).to_i,
      }
    end
  end
end
