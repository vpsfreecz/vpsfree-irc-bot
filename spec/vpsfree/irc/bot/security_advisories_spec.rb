# frozen_string_literal: true

require 'spec_helper'
require 'timeout'

module SecurityAdvisoriesSpec
  Advisory = Struct.new(:id, :state, :published_at, :name, :en_summary, :affected_node_count)
  Update = Struct.new(:security_advisory, :created_at, :state, :en_summary, :reporter_name)
  Resource = Struct.new(:rows) do
    def list(**_params)
      rows
    end
  end
  SystemConfig = Struct.new(:value) do
    def show(*_args)
      self
    end
  end
  TestApi = Struct.new(:system_config, :security_advisory, :security_advisory_update, :security_advisory_cve)
end

RSpec.describe VpsFree::Irc::Bot::SecurityAdvisories do
  def advisories
    api.security_advisory
  end

  def updates
    api.security_advisory_update
  end

  def cves
    api.security_advisory_cve
  end

  let(:api) do
    SecurityAdvisoriesSpec::TestApi.new(
      SecurityAdvisoriesSpec::SystemConfig.new('https://admin.example.test/panel/'),
      *Array.new(3) { SecurityAdvisoriesSpec::Resource.new([]) }
    )
  end
  let(:store) { {} }
  let(:channel) { instance_double(Cinch::Channel, name: '#vpsfree') }
  let(:announcements) { [] }

  def clock
    @clock ||= { monotonic: 100.0, wall: Time.iso8601('2026-10-19T12:00:00Z') }
  end

  before do
    clock
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { clock[:monotonic] }
    allow(Time).to receive(:now) { clock[:wall] }
    allow(VpsFree::Irc::Bot::FileStorage).to receive(:new).and_return(store)
  end

  it 'defaults to individual mode and leaves an absent plugin disabled' do
    plugin = build_plugin
    plugin.post_api_setup
    advisories.rows = [advisory(1)]
    plugin.check

    expect(messages.join).to include('New security advisory #1', 'Summary: Summary 1')
    expect(VpsFree::Irc::Bot.configured_plugins(api_url: 'https://api.example.test')).not_to include(described_class)
  end

  %w[individual summary off].each do |mode|
    it "accepts #{mode} mode" do
      expect { build_plugin(mode: mode) }.not_to raise_error
    end
  end

  [nil, '', 'digest', :summary, false].each do |mode|
    it "rejects invalid mode #{mode.inspect} at initialization" do
      expect { build_plugin(mode: mode) }.to raise_error(ArgumentError, /mode must be/)
    end
  end

  [nil, 0, -1, 1.5, '3600', true].each do |interval|
    it "rejects invalid interval #{interval.inspect} even outside summary mode" do
      expect { build_plugin(summary_interval: interval) }.to raise_error(ArgumentError, /positive integer/)
    end
  end

  it 'uses a full hour by default' do
    plugin = build_plugin(mode: 'summary')
    plugin.post_api_setup
    poll(plugin, new: [advisory(1)])
    clock[:monotonic] += 3599
    plugin.flush_summary
    expect(messages).to be_empty
    clock[:monotonic] += 1
    plugin.flush_summary
    expect(messages).to eq(['1 new security advisory in vpsAdmin: https://admin.example.test/panel/?page=security_advisory'])
  end

  it 'keeps individual update details, eligibility and routing' do
    plugin = build_plugin(mode: 'individual')
    plugin.post_api_setup
    poll(plugin, new: [advisory(1), advisory(2, state: 'retracted')])
    poll(plugin, updates: [update(advisory(1, state: 'retracted'))])

    expect(messages.join).to include('New security advisory #1', 'Update of security advisory #1', 'State: retracted')
    expect(messages.join).not_to include('New security advisory #2')
    expect(messages.last).to eq('https://admin.example.test/panel/?page=security_advisory&action=show&id=1')
    expect(announcements.map(&:first).uniq).to eq([channel])
  end

  describe 'summary windows' do
    let(:plugin) { build_plugin(mode: 'summary', summary_interval: 10) }

    before { plugin.post_api_setup }

    it 'accumulates gradual arrivals without moving the deadline or sending early' do
      poll(plugin, new: [advisory(1)])
      plugin.flush_summary
      clock[:monotonic] = 105
      poll(plugin, new: [advisory(2)])
      clock[:monotonic] = 109
      plugin.flush_summary
      expect(messages).to be_empty

      clock[:monotonic] = 110
      plugin.flush_summary
      expect(messages).to eq(["2 new security advisories in vpsAdmin: #{list_url}"])
      expect(announcements.map(&:first)).to eq([channel])
    end

    it 'counts distinct IDs across polls, giving new precedence for the whole window' do
      old = advisory(9)
      store[9] = {}
      poll(plugin, new: [advisory(1)], updates: [update(old), update(old), update(advisory(1))])
      poll(plugin, new: [advisory(1)], updates: [update(old), update(advisory(1)), update(advisory(8))])
      clock[:monotonic] = 110
      plugin.flush_summary

      expect(messages).to eq(["1 new security advisory, 2 updated in vpsAdmin: #{list_url}"])
    end

    it 'removes an earlier update count when the same ID becomes new within a window' do
      poll(plugin, updates: [update(advisory(1))])
      # Model a previously invisible advisory becoming eligible for its first new notice.
      store.delete(1)
      poll(plugin, new: [advisory(1)])
      clock[:monotonic] = 110
      plugin.flush_summary

      expect(messages).to eq(["1 new security advisory in vpsAdmin: #{list_url}"])
    end

    it 'reports update-only and retraction windows with singular and plural labels' do
      poll(plugin, new: [advisory(1, state: 'retracted')],
                   updates: [update(advisory(1, state: 'retracted')), update(nil)])
      clock[:monotonic] = 110
      plugin.flush_summary
      poll(plugin, updates: [update(advisory(1)), update(advisory(2))])
      clock[:monotonic] = 120
      plugin.flush_summary

      expect(messages).to eq([
                               "1 security advisory updated in vpsAdmin: #{list_url}",
                               "2 security advisories updated in vpsAdmin: #{list_url}"
                             ])
      expect(store[1][:state]).to eq('published')
    end

    it 'does not flush a large batch early or introduce API pagination limits' do
      allow(advisories).to receive(:list).and_call_original
      allow(updates).to receive(:list).and_call_original
      allow(cves).to receive(:list).and_call_original
      poll(plugin, new: (1..250).map { |id| advisory(id) })
      plugin.flush_summary
      expect(messages).to be_empty
      clock[:monotonic] = 110
      plugin.flush_summary

      expect(messages).to eq(["250 new security advisories in vpsAdmin: #{list_url}"])
      expect(advisories).to have_received(:list).with(recent_since: clock[:wall].iso8601)
      expect(updates).to have_received(:list).with(since: clock[:wall].iso8601, meta: { includes: 'security_advisory' })
      expect(cves).to have_received(:list).with(security_advisory: 250)
      expect(store.size).to eq(250)
    end

    it 'flushes pending counts independently after an empty or failed poll' do
      poll(plugin, new: [advisory(1)])
      poll(plugin)
      allow(advisories).to receive(:list).and_raise(StandardError, 'API unavailable')
      plugin.check
      clock[:monotonic] = 110
      plugin.flush_summary

      expect(messages).to eq(["1 new security advisory in vpsAdmin: #{list_url}"])
    end

    it 'skips empty windows and still advances their deadlines' do
      clock[:monotonic] = 110
      plugin.flush_summary
      poll(plugin, new: [advisory(1)])
      clock[:monotonic] = 119
      plugin.flush_summary
      expect(messages).to be_empty
      clock[:monotonic] = 120
      plugin.flush_summary
      clock[:monotonic] = 130
      plugin.flush_summary

      expect(messages.size).to eq(1)
    end

    it 'starts a full interval after delayed handling without catch-up bursts' do
      poll(plugin, new: [advisory(1)])
      clock[:monotonic] = 155
      plugin.flush_summary
      poll(plugin, new: [advisory(2)])
      plugin.flush_summary
      clock[:monotonic] = 164
      plugin.flush_summary
      expect(messages.size).to eq(1)
      clock[:monotonic] = 165
      plugin.flush_summary
      expect(messages.size).to eq(2)
    end

    it 'spaces sends by a full interval after a slow output attempt finishes' do
      allow(plugin).to receive(:send_channels) do |msg|
        announcements << [channel, msg]
        clock[:monotonic] += 5
      end
      poll(plugin, new: [advisory(1)])
      clock[:monotonic] = 110
      plugin.flush_summary
      poll(plugin, new: [advisory(2)])
      clock[:monotonic] = 124
      plugin.flush_summary
      expect(messages.size).to eq(1)
      clock[:monotonic] = 125
      plugin.flush_summary
      expect(messages.size).to eq(2)
    end

    it 'ignores wall-clock jumps for deadlines' do
      poll(plugin, new: [advisory(1)])
      clock[:wall] += 86_400
      plugin.flush_summary
      expect(messages).to be_empty
      clock[:wall] -= 172_800
      clock[:monotonic] = 110
      plugin.flush_summary
      expect(messages.size).to eq(1)
    end

    it 'discards failed output and waits a full interval before the next attempt' do
      allow(plugin).to receive(:send_channels).and_raise(StandardError, 'send failed')
      poll(plugin, new: [advisory(1)])
      clock[:monotonic] = 110
      plugin.flush_summary
      allow(plugin).to receive(:send_channels).and_call_original
      poll(plugin, new: [advisory(2)])
      clock[:monotonic] = 119
      plugin.flush_summary
      expect(messages).to be_empty
      clock[:monotonic] = 120
      plugin.flush_summary
      expect(messages).to eq(["1 new security advisory in vpsAdmin: #{list_url}"])
    end

    it 'discards muted output instead of replaying it' do
      allow(plugin).to receive(:log_mutable_send).and_call_original
      allow(VpsFree::Irc::Bot::State.get).to receive(:muted?).and_return(true)
      allow(plugin).to receive(:log_send)
      poll(plugin, new: [advisory(1)])
      clock[:monotonic] = 110
      plugin.flush_summary
      allow(VpsFree::Irc::Bot::State.get).to receive(:muted?).and_return(false)
      clock[:monotonic] = 120
      plugin.flush_summary

      expect(plugin).not_to have_received(:log_send)
    end

    it 'keeps a failed poll out of the counts, store and watermark, then retries it' do
      poll(plugin, new: [advisory(1)])
      clock[:wall] += 60
      advisories.rows = [advisory(2)]
      allow(updates).to receive(:list).and_raise(StandardError, 'query failed')
      plugin.check
      expect(store.keys).to eq([1])
      clock[:monotonic] = 110
      plugin.flush_summary
      expect(messages).to eq(["1 new security advisory in vpsAdmin: #{list_url}"])

      allow(advisories).to receive(:list).and_call_original
      allow(updates).to receive(:list).and_call_original
      plugin.check
      expect(advisories).to have_received(:list).with(recent_since: (clock[:wall] - 60).iso8601)
      clock[:monotonic] = 120
      plugin.flush_summary
      expect(messages.size).to eq(2)
      expect(store.keys).to eq([1, 2])
    end

    it 'serializes a due flush with an in-progress poll' do
      entered = Queue.new
      release = Queue.new
      flush_started = Queue.new
      poll(plugin, new: [advisory(1)])
      advisories.rows = [advisory(2)]
      allow(updates).to receive(:list) do
        entered << true
        release.pop
        []
      end
      clock[:monotonic] = 110
      poll_thread = Thread.new { plugin.check }
      Timeout.timeout(2) { entered.pop }
      flush_thread = Thread.new do
        flush_started << true
        plugin.flush_summary
      end
      Timeout.timeout(2) do
        flush_started.pop
        Thread.pass while flush_thread.alive? && flush_thread.status != 'sleep'
      end
      expect(messages).to be_empty
      release << true
      Timeout.timeout(2) do
        poll_thread.value
        flush_thread.value
      end
      expect(messages).to eq(["2 new security advisories in vpsAdmin: #{list_url}"])
    ensure
      release << true
      poll_thread&.join(2)
      flush_thread&.join(2)
    end
  end

  it 'silently bootstraps recent advisories before starting the full interval' do
    plugin = build_plugin(mode: 'summary', summary_interval: 10)
    advisories.rows = [advisory(1)]
    allow(advisories).to receive(:list).and_call_original
    clock[:monotonic] = 200
    plugin.post_api_setup
    poll(plugin, new: [advisory(2)])
    clock[:monotonic] = 209
    plugin.flush_summary
    expect(messages).to be_empty
    clock[:monotonic] = 210
    plugin.flush_summary

    expect(messages).to eq(["1 new security advisory in vpsAdmin: #{list_url}"])
    expect(advisories).to have_received(:list).with(recent_since: (clock[:wall] - (30 * 86_400)).iso8601)
    expect(store.keys).to eq([1, 2])
  end

  it 'retries failed bootstrap lists silently and waits a full interval after recovery' do
    plugin = build_plugin(mode: 'summary', summary_interval: 10)
    original_since = clock[:wall].iso8601
    historical = advisory(1)
    failure = StandardError.new('bootstrap list failed')
    attempts = 0
    allow(updates).to receive(:list).and_call_original
    allow(advisories).to receive(:list) do
      attempts += 1
      raise failure if attempts <= 2

      [historical]
    end

    expect { plugin.post_api_setup }.to raise_error(failure)
    clock[:monotonic] = 120
    clock[:wall] += 60
    plugin.check
    plugin.flush_summary
    expect(messages).to be_empty
    expect(updates).not_to have_received(:list)
    expect(store).to be_empty

    clock[:monotonic] = 130
    plugin.check
    plugin.flush_summary
    expect(messages).to be_empty
    expect(store.keys).to eq([1])
    allow(advisories).to receive(:list).and_call_original
    poll(plugin, new: [historical, advisory(2)])
    expect(advisories).to have_received(:list).with(recent_since: original_since)
    expect(VpsFree::Irc::Bot::FileStorage).to have_received(:new).once
    clock[:monotonic] = 139
    plugin.flush_summary
    expect(messages).to be_empty
    clock[:monotonic] = 140
    plugin.flush_summary
    expect(messages).to eq(["1 new security advisory in vpsAdmin: #{list_url}"])
  end

  %w[individual summary off].each do |mode|
    it "recovers a partial CVE bootstrap silently in #{mode} mode" do
      plugin = build_plugin(mode: mode, summary_interval: 10)
      historical = [advisory(1), advisory(2)]
      advisories.rows = historical
      allow(cves).to receive(:list).and_call_original
      allow(cves).to receive(:list).with(security_advisory: 1).and_return([])
      allow(cves).to receive(:list).with(security_advisory: 2).and_raise(StandardError, 'CVE read failed')
      allow(updates).to receive(:list).and_call_original

      expect { plugin.post_api_setup }.to raise_error(StandardError, 'CVE read failed')
      expect(store.keys).to eq([1])
      clock[:monotonic] = 120
      allow(cves).to receive(:list).with(security_advisory: 2).and_return([])
      plugin.check
      plugin.flush_summary
      expect(messages).to be_empty
      expect(store.keys).to eq([1, 2])
      expect(updates).not_to have_received(:list)
      expect(VpsFree::Irc::Bot::FileStorage).to have_received(:new).once

      poll(plugin, new: historical + [advisory(3)])
      clock[:monotonic] = 130
      plugin.flush_summary
      if mode == 'individual'
        expect(messages.join).to include('New security advisory #3')
        expect(messages.join).not_to include('New security advisory #1', 'New security advisory #2')
      elsif mode == 'summary'
        expect(messages).to eq(["1 new security advisory in vpsAdmin: #{list_url}"])
      else
        expect(messages).to be_empty
      end
      expect(store.keys).to eq([1, 2, 3])
    end
  end

  it 'discards pending counts on restart and starts a new full interval' do
    first = build_plugin(mode: 'summary', summary_interval: 10)
    first.post_api_setup
    poll(first, new: [advisory(1)])
    clock[:monotonic] = 105
    second = build_plugin(mode: 'summary', summary_interval: 10)
    second.post_api_setup
    poll(second, new: [advisory(2)])
    clock[:monotonic] = 110
    second.flush_summary
    expect(messages).to be_empty
    clock[:monotonic] = 115
    second.flush_summary

    expect(messages).to eq(["1 new security advisory in vpsAdmin: #{list_url}"])
  end

  it 'consumes off-mode events and updates silently without accumulating a later digest' do
    plugin = build_plugin(mode: 'off', summary_interval: 10)
    plugin.post_api_setup
    clock[:wall] += 60
    poll(plugin, new: [advisory(1)], updates: [update(advisory(1, state: 'retracted'))])
    allow(advisories).to receive(:list).and_call_original
    poll(plugin)
    clock[:monotonic] = 500
    plugin.flush_summary

    expect(store[1][:state]).to eq('retracted')
    expect(advisories).to have_received(:list).with(recent_since: clock[:wall].iso8601)
    expect(messages).to be_empty
    expect(plugin.instance_variable_get(:@pending_new)).to be_empty
    expect(plugin.instance_variable_get(:@pending_updated)).to be_empty
  end

  def build_plugin(**options)
    plugin_class = described_class
    settings = {
      server_label: 'test', api_url: 'https://api.example.test',
      state_dir: '/unused', channels: ['#vpsfree']
    }.merge(options)
    bot = Cinch::Bot.new do
      configure { |config| config.plugins.options[plugin_class] = settings }
      loggers.clear
    end
    allow(bot).to receive(:channels).and_return([channel, instance_double(Cinch::Channel, name: '#elsewhere')])
    plugin = described_class.new(bot)
    allow(plugin).to receive(:client).and_yield(api)
    allow(plugin).to receive(:api_setup?).and_return(true)
    allow(plugin).to receive(:exception)
    allow(plugin).to receive(:log_mutable_send) { |target, msg, _type| announcements << [target, msg] }
    plugin
  end

  def poll(plugin, new: [], updates: [])
    advisories.rows = new
    self.updates.rows = updates
    plugin.check
  end

  def advisory(id, state: 'published')
    SecurityAdvisoriesSpec::Advisory.new(id, state, clock[:wall].iso8601, "Advisory #{id}", "Summary #{id}", 0)
  end

  def update(advisory)
    SecurityAdvisoriesSpec::Update.new(advisory, clock[:wall].iso8601, advisory&.state, 'Updated summary', 'Admin')
  end

  def messages
    announcements.map(&:last)
  end

  def list_url
    'https://admin.example.test/panel/?page=security_advisory'
  end
end
