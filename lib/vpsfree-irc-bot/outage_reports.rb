require 'cinch'
require 'date'
require 'vpsfree-irc-bot/api'
require 'vpsfree-irc-bot/command'
require 'vpsfree-irc-bot/helpers'

module VpsFree::Irc::Bot
  class OutageReports
    include Cinch::Plugin
    include Helpers
    include Api
    include Command

    REMINDERS = [
      [0, 'Ladies and gentlemen, we are going DOWN!'],
      [1 * 60, 'a minute'],
      [10 * 60, '10 minutes'],
      [30 * 60, '30 minutes'],
      [1 * 60 * 60, 'an hour'],
      [6 * 60 * 60, 'six hours']
    ].freeze

    OUTAGE_TYPE_LABELS = {
      'planned_outage' => 'planned outage',
      'unplanned_outage' => 'unplanned outage'
    }.freeze

    IMPACT_LABELS = {
      'tbd' => 'TBD',
      'system_restart' => 'System restart',
      'system_reset' => 'System reset',
      'network' => 'Network',
      'performance' => 'Performance',
      'unavailability' => 'Unavailability',
      'export' => 'NFS export'
    }.freeze

    set required_options: %i[server_label api_url channels state_dir]

    timer ENV.fetch('VPSFREE_IRC_BOT_OUTAGE_CHECK_INTERVAL', 60).to_i, method: :check, threaded: false
    timer ENV.fetch('VPSFREE_IRC_BOT_OUTAGE_REMIND_INTERVAL', 30).to_i, method: :remind, threaded: false

    command :outage do
      desc 'show current/selected outage'
      arg :id, required: false
      aliases :outage?, :issue, :issue?
    end

    def post_api_setup
      @webui = client { |api| api.system_config.show('webui', 'base_url').value }
      @store = FileStorage.new(config[:state_dir], config[:server_label], :outages)
      @since = Time.now

      client do |api|
        # Refresh info about outages
        outages = api.outage.list(state: :announced)
        outages.each do |outage|
          @store[outage.id] = outage_to_hash(outage)
        end

        # Remove closed/cancelled outages
        @store.delete_if do |id, _outage|
          !outages.detect { |o| o.id == id }
        end
      end
    end

    def check
      unless api_setup?
        warn 'Skipping outage check, API not set up'
        return
      end

      client do |api|
        outages = api.outage.list(state: :announced, since: @since)
        outages.each do |outage|
          next if @store[outage.id]

          @store[outage.id] = outage_to_hash(outage)
          report_outage(outage)
        end

        updates = api.outage_update.list(since: @since, meta: { includes: 'outage' })
        updates.each do |update|
          report_update(update)
        end

        @since = Time.now if !outages.empty? || !updates.empty?
      end
    rescue StandardError => e
      exception(e)
    end

    def remind
      unless api_setup?
        warn 'Skipping outage reminder, API not set up'
        return
      end

      now = Time.now.to_i

      @store.each do |id, outage|
        REMINDERS.each do |t, msg|
          delta = outage[:begins_at] - now

          next if delta > t
          break if outage[:reminded] == t || (t - delta) > 60

          if t == 0
            send_channels("#{outage_type_label(outage[:type], capitalize: true)} ##{id} has begun: #{msg}")

          else
            label = outage_type_label(outage[:type], capitalize: true)
            send_channels("#{label} ##{id} begins in #{msg} (#{fmt_date(outage[:begins_at])})")
          end

          outage[:reminded] = t
          break
        end
      end
    end

    def cmd_outage(m, _channel, raw_id = nil)
      unless api_setup?
        return reply(m, 'Status unknown, unable to reach vpsAdmin API')
      end

      # Show selected outage
      if raw_id
        id = raw_id.to_i

        client do |api|
          describe_outage(
            id,
            outage_to_hash(api.outage.show(id)),
            m
          )
        rescue HaveAPI::Client::ActionFailed => e
          reply(m, "Outage '#{id}' not found")
        end

        return
      end

      # Show current outages
      return reply(m, 'No outage reported') if @store.empty?

      now = Time.now.to_i

      relevant = @store.select { |_id, outage| outage[:begins_at] <= Time.now.to_i }
      return reply(m, 'No relevant outage reported currently') if relevant.empty?

      relevant.each do |id, outage|
        describe_outage(id, outage, m)
      end
    end

    protected

    def report_outage(outage)
      send_channels(<<~END
        New #{outage_type_label(outage.type)} ##{outage.id} reported at #{fmt_date(outage.begins_at)}
             Systems: #{outage.entity.list.map(&:label).join(', ')}
              Impact: #{impact_label(outage.impact)}
            Duration: #{outage.duration} minutes
              Reason: #{outage.en_summary}
          Handled by: #{outage.handler.list.map(&:full_name).join(', ')}
        #{outage_url(outage.id)}
      END
                   )
    rescue StandardError => e
      exception(e)
    end

    def report_update(update)
      if update.state == 'announced'
        return if @store[update.outage_id]

        @store[update.outage_id] = outage_to_hash(update.outage)
        report_outage(update.outage)
        return
      end

      attrs = %i[begins_at finished_at state impact duration]
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

        when :impact
          changes << "     Impact: #{impact_label(v)}"
        end
      end

      if update.outage.state == 'announced'
        @store[update.outage_id] = outage_to_hash(update.outage)

      else
        @store.delete(update.outage_id)
      end

      update_label = outage_type_label(update.type)
      send_channels("Update of #{update_label} ##{update.outage_id} at #{fmt_date(update.created_at)}")
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
      raise 'vpsAdmin WebUI base URL is not configured' if @webui.nil? || @webui.empty?

      File.join(@webui, "?page=outage&action=show&id=#{id}")
    end

    def outage_type(type)
      case type.to_s
      when 'maintenance'
        'planned_outage'
      when 'outage'
        'unplanned_outage'
      else
        type.to_s
      end
    end

    def outage_type_label(type, capitalize: false)
      label = OUTAGE_TYPE_LABELS.fetch(outage_type(type), type.to_s.tr('_', ' '))

      if capitalize && !label.empty?
        label[0].upcase + (label[1..] || '')
      else
        label
      end
    end

    def impact_label(impact)
      IMPACT_LABELS.fetch(impact.to_s, impact.to_s.tr('_', ' '))
    end

    def send_channels(msg)
      bot.channels.each do |c|
        next unless config[:channels].include?(c.name)

        log_mutable_send(c, msg, :notice)
      end
    end

    def outage_to_hash(outage)
      {
        type: outage_type(outage.type),
        begins_at: get_date(outage.begins_at).to_i,
        duration: outage.duration,
        impact: outage.impact,
        summary: outage.en_summary,
        entities: outage.entity.list.map(&:label),
        handlers: outage.handler.list.map(&:full_name)
      }
    end

    def describe_outage(id, outage, m)
      reply(m, <<~END
        #{outage_type_label(outage[:type], capitalize: true)} ##{id} reported at #{fmt_date(outage[:begins_at])}
             Systems: #{outage[:entities].join(', ')}
              Impact: #{impact_label(outage[:impact])}
            Duration: #{outage[:duration]} minutes
              Reason: #{outage[:summary]}
          Handled by: #{outage[:handlers].join(', ')}
        #{outage_url(id)}
      END
      )
    end
  end
end
