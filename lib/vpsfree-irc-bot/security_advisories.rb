require 'cinch'
require 'date'
require 'time'
require 'vpsfree-irc-bot/api'
require 'vpsfree-irc-bot/helpers'

module VpsFree::Irc::Bot
  class SecurityAdvisories
    include Cinch::Plugin
    include Helpers
    include Api

    RECENT_DAYS = 30

    set required_options: %i[server_label api_url channels state_dir]

    timer ENV.fetch('VPSFREE_IRC_BOT_SECURITY_ADVISORY_CHECK_INTERVAL', 60).to_i, method: :check, threaded: false
    timer 1, method: :flush_summary, threaded: false

    def initialize(*)
      super

      @mode = config.fetch(:mode, 'individual')
      @summary_interval = config.fetch(:summary_interval, 3600)
      unless %w[individual summary off].include?(@mode)
        raise ArgumentError, 'security_advisories.mode must be individual, summary or off'
      end
      unless @summary_interval.is_a?(Integer) && @summary_interval > 0
        raise ArgumentError, 'security_advisories.summary_interval must be a positive integer in seconds'
      end

      @advisory_mutex = Mutex.new
      @pending_new = Set.new
      @pending_updated = Set.new
    end

    def post_api_setup
      @advisory_mutex.synchronize do
        @advisories_initialized = false
        @summary_deadline = nil
        @store = FileStorage.new(config[:state_dir], config[:server_label], :security_advisories)
        @since = Time.now
        initialize_advisories
      end
    end

    def check
      @advisory_mutex.synchronize do
        unless api_setup?
          warn 'Skipping security advisory check, API not set up'
          return
        end

        unless @advisories_initialized
          # Retry incomplete bootstrap without polling or announcing its history.
          initialize_advisories if @store
          return
        end

        client do |api|
          if @mode == 'individual'
            check_individual(api)
          else
            check_silent(api)
          end
        end
      end
    rescue StandardError => e
      exception(e)
    end

    def flush_summary
      return unless @mode == 'summary'

      @advisory_mutex.synchronize do
        return unless @summary_deadline && monotonic_time >= @summary_deadline

        begin
          report_summary unless @pending_new.empty? && @pending_updated.empty?
        ensure
          @pending_new.clear
          @pending_updated.clear
          # Start a full interval after handling, including delayed or failed sends.
          @summary_deadline = monotonic_time + @summary_interval
        end
      end
    rescue StandardError => e
      exception(e)
    end

    protected

    def initialize_advisories
      @webui = client { |api| api.system_config.show('webui', 'base_url').value }

      client do |api|
        advisories = api.security_advisory.list(
          recent_since: (Time.now - (RECENT_DAYS * 24 * 60 * 60)).iso8601
        )
        advisories.each do |advisory|
          @store[advisory.id] = advisory_to_hash(advisory, advisory_cves(api, advisory.id))
        end
      end
      @summary_deadline = monotonic_time + @summary_interval
      @advisories_initialized = true
    end

    def check_individual(api)
      advisories = api.security_advisory.list(recent_since: @since.iso8601)
      advisories.each do |advisory|
        next if @store[advisory.id]

        cves = advisory_cves(api, advisory.id)
        @store[advisory.id] = advisory_to_hash(advisory, cves)
        report_advisory(advisory, cves) if advisory.state == 'published'
      end

      updates = api.security_advisory_update.list(
        since: @since.iso8601,
        meta: { includes: 'security_advisory' }
      )
      updates.each do |update|
        report_update(api, update)
      end

      @since = Time.now if !advisories.empty? || !updates.empty?
    end

    def check_silent(api)
      snapshots = {}
      new_ids = Set.new
      updated_ids = Set.new
      advisories = api.security_advisory.list(recent_since: @since.iso8601)
      advisories.each do |advisory|
        next if @store[advisory.id] || snapshots.has_key?(advisory.id)

        snapshots[advisory.id] = advisory_to_hash(advisory, advisory_cves(api, advisory.id))
        new_ids.add(advisory.id) if advisory.state == 'published'
      end

      updates = api.security_advisory_update.list(
        since: @since.iso8601,
        meta: { includes: 'security_advisory' }
      )
      updates.each do |update|
        advisory = update.security_advisory
        next unless advisory

        snapshots[advisory.id] = advisory_to_hash(advisory, advisory_cves(api, advisory.id))
        updated_ids.add(advisory.id)
      end

      # Commit counts only after both queries and all snapshot reads succeed.
      snapshots.each { |id, snapshot| @store[id] = snapshot }
      if @mode == 'summary'
        @pending_new.merge(new_ids)
        @pending_updated.merge(updated_ids).subtract(@pending_new)
      end
      @since = Time.now if !advisories.empty? || !updates.empty?
    end

    def report_summary
      categories = []
      unless @pending_new.empty?
        count = @pending_new.size
        categories << "#{count} new security #{count == 1 ? 'advisory' : 'advisories'}"
      end
      unless @pending_updated.empty?
        count = @pending_updated.size
        noun = count == 1 ? 'advisory' : 'advisories'
        label = @pending_new.empty? ? "security #{noun} " : ''
        categories << "#{count} #{label}updated"
      end

      send_channels("#{categories.join(', ')} in vpsAdmin: #{security_advisory_list_url}")
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def report_advisory(advisory, cves)
      send_channels(<<~END
        New security advisory ##{advisory.id} published at #{fmt_date(advisory.published_at)}
              CVE: #{advisory_label(advisory, cves)}
          Summary: #{advisory.en_summary}
        #{security_advisory_url(advisory.id)}
      END
                   )
    rescue StandardError => e
      exception(e)
    end

    def report_update(api, update)
      advisory = update.security_advisory
      return unless advisory

      @store[advisory.id] = advisory_to_hash(advisory, advisory_cves(api, advisory.id))

      send_channels("Update of security advisory ##{advisory.id} at #{fmt_date(update.created_at)}")
      send_channels("     State: #{update.state}") if update.state && !update.state.empty?
      send_channels("   Summary: #{update.en_summary}") if update.en_summary && !update.en_summary.empty?
      send_channels("Reported by: #{update.reporter_name}") if update.reporter_name && !update.reporter_name.empty?
      send_channels(security_advisory_url(advisory.id))
    rescue StandardError => e
      exception(e)
    end

    def get_date(v)
      DateTime.iso8601(v).to_time.localtime
    end

    def fmt_date(v)
      (v.is_a?(Integer) ? Time.at(v) : get_date(v)).strftime('%Y-%m-%d %H:%M %Z')
    end

    def advisory_label(advisory, cves)
      cve_ids = cves.map(&:cve_id).join(', ')

      if !cve_ids.empty? && advisory.name && !advisory.name.empty?
        "#{cve_ids} (#{advisory.name})"
      elsif !cve_ids.empty?
        cve_ids
      else
        advisory.name
      end
    end

    def security_advisory_url(id)
      raise 'vpsAdmin WebUI base URL is not configured' if @webui.nil? || @webui.empty?

      File.join(@webui, "?page=security_advisory&action=show&id=#{id}")
    end

    def security_advisory_list_url
      raise 'vpsAdmin WebUI base URL is not configured' if @webui.nil? || @webui.empty?

      File.join(@webui, '?page=security_advisory')
    end

    def send_channels(msg)
      bot.channels.each do |c|
        next unless config[:channels].include?(c.name)

        log_mutable_send(c, msg, :notice)
      end
    end

    def advisory_cves(api, advisory_id)
      api.security_advisory_cve.list(security_advisory: advisory_id).to_a
    end

    def advisory_to_hash(advisory, cves)
      {
        state: advisory.state,
        published_at: get_date(advisory.published_at).to_i,
        cves: cves.map { |cve| { id: cve.id, cve_id: cve.cve_id, url: cve.url } },
        name: advisory.name,
        summary: advisory.en_summary,
        affected_node_count: advisory.affected_node_count
      }
    end
  end
end
