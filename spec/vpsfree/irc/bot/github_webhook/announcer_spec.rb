# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VpsFree::Irc::Bot::GitHubWebHook::Announcer do
  it 'keeps legacy channel lists unrestricted by event type and branch' do
    channels = described_class.normalize_channels(
      '#vpsadminos' => ['vpsfreecz/vpsadminos']
    )

    expect(
      described_class.announce_in_channel?(
        channels['#vpsadminos'],
        push_event(
          repository: 'vpsfreecz/vpsadminos',
          default_branch: 'master',
          ref: 'refs/heads/feature'
        )
      )
    ).to be(true)

    expect(
      described_class.announce_in_channel?(
        channels['#vpsadminos'],
        create_event(repository: 'vpsfreecz/vpsadminos')
      )
    ).to be(true)
  end

  it 'accepts pushes to the configured repository default branch' do
    expect(
      described_class.announce_in_channel?(
        filtered_channel,
        push_event(default_branch: 'master', ref: 'refs/heads/master')
      )
    ).to be(true)
  end

  it 'rejects pushes to non-default branches' do
    expect(
      described_class.announce_in_channel?(
        filtered_channel,
        push_event(default_branch: 'master', ref: 'refs/heads/topic')
      )
    ).to be(false)
  end

  it 'keeps issues and pull requests in filtered channels' do
    expect(described_class.announce_in_channel?(filtered_channel, issue_event)).to be(true)
    expect(described_class.announce_in_channel?(filtered_channel, pull_request_event)).to be(true)
  end

  it 'rejects event types that are not allowed in filtered channels' do
    expect(described_class.announce_in_channel?(filtered_channel, create_event)).to be(false)
    expect(described_class.announce_in_channel?(filtered_channel, delete_event)).to be(false)
    expect(described_class.announce_in_channel?(filtered_channel, fork_event)).to be(false)
  end

  it 'requires a repository default branch for default-branch push matching' do
    expect(
      described_class.announce_in_channel?(
        filtered_channel,
        push_event(default_branch: nil, ref: 'refs/heads/master')
      )
    ).to be(false)
  end

  it 'normalizes string and symbol keys and ignored-user values' do
    configs = [
      { repositories: ['vpsfreecz/web'], ignored_users: [:automation] },
      { 'repositories' => ['vpsfreecz/web'], 'ignored_users' => ['automation'] }
    ].map { |config| described_class.normalize_channel_config(config) }

    expect(configs.map(&:ignored_users)).to eq([['automation'], ['automation']])
    expect(described_class.normalize_channel_config(configs.first)).to equal(configs.first)
  end

  it 'preserves exact legacy rendering for absent and empty ignored lists' do
    event = push_event(commits: Array.new(11) { push_commit('github-actions[bot]') }, sender: 'github-actions[bot]')
    configs = [
      ['vpsfreecz/web'],
      { repositories: ['vpsfreecz/web'] },
      { repositories: ['vpsfreecz/web'], ignored_users: [] }
    ]

    configs.each do |config|
      expect(described_class.announcement_in_channel(config, event)).to eq(event.to_s)
    end
  end

  it 'keeps human and unknown authors despite an ignored sender or contradictory email' do
    event = push_event(
      sender: 'github-actions[bot]',
      commits: [
        push_commit('github-actions[bot]', message: 'Ignored'),
        push_commit('human', email: 'github-actions[bot]@users.noreply.github.com', message: 'Human'),
        push_commit(nil, message: 'Unknown')
      ]
    )
    text = announcement(event)

    expect(text).to include('pushed 2 announced commits (1 ignored)')
    expect(text).to include('Tester: Human', 'Tester: Unknown')
    expect(text).not_to include('Tester: Ignored')
    expect(text.index('Tester: Human')).to be < text.index('Tester: Unknown')
  end

  it 'ignores original authors without consulting sender, pusher or committer' do
    event = push_event(
      sender: 'human',
      commits: [
        push_commit('github-actions[bot]', email: 'human@example.org'),
        push_commit(nil, email: '41898282+github-actions[bot]@users.noreply.github.com'),
        push_commit('', email: 'github-actions[bot]@users.noreply.github.com')
      ]
    )

    expect(announcement(event)).to be_nil
  end

  [false, true].product([false, true], ['human', 'github-actions[bot]']).each do |forced, distinct, sender|
    it "suppresses all-ignored pushes with forced=#{forced}, distinct=#{distinct}, sender=#{sender}" do
      event = push_event(
        forced: forced, sender: sender, commits: [push_commit('github-actions[bot]', distinct: distinct)]
      )

      expect(announcement(event)).to be_nil
    end
  end

  it 'caps active-filter output at ten even when no authors are excluded' do
    event = push_event(commits: Array.new(11) { |i| push_commit('human', message: "Human #{i}") })
    text = announcement(event)

    expect(text).to include('pushed 11 commits', '...and 1 more commits')
    expect(text.lines.grep(/Tester: Human/).length).to eq(10)
    expect(text).not_to include('announced', 'Human 10')
  end

  it 'keeps exact and case-sensitive ignored-user matching' do
    event = push_event(commits: [push_commit('GitHub-actions[bot]'), push_commit(' github-actions[bot]')])

    expect(announcement(event)).to include('pushed 2 commits')
  end

  it 'filters originally empty eligible pushes by sender and keeps legacy ref updates' do
    human = push_event(commits: [], sender: 'human')
    ignored = push_event(commits: [], sender: 'github-actions[bot]')

    expect(announcement(human)).to eq(human.to_s)
    expect(announcement(ignored)).to be_nil
  end

  it 'keeps the repository, event-type and branch gates before filtering' do
    events = [
      push_event(repository: 'other/web'),
      push_event(ref: 'refs/heads/topic'),
      create_event
    ]

    events.each { |event| expect(announcement(event, config: filtered_channel)).to be_nil }
  end

  %i[create_event delete_event fork_event issue_event pull_request_event].each do |factory|
    it "filters #{factory} by sender rather than creator" do
      ignored = send(factory, sender: 'github-actions[bot]')
      human = send(factory, sender: 'human')
      unknown = send(factory, sender: nil)

      expect(announcement(ignored)).to be_nil
      expect(announcement(human)).to eq(human.to_s)
      expect(announcement(unknown)).to eq(unknown.to_s)
    end
  end

  it 'does not alter a shared event across different channel orders' do
    event = push_event(commits: [push_commit('github-actions[bot]'), push_commit('human')])
    original = Marshal.dump(event)
    configs = [ignored_channel, ['vpsfreecz/web']]

    [configs, configs.reverse].each do |ordered|
      texts = ordered.map { |config| described_class.announcement_in_channel(config, event) }

      expect(texts).to include(event.to_s)
      expect(texts).to include(announcement(event))
      expect(Marshal.dump(event)).to eq(original)
    end
  end

  it 'skips both sending and logging for a suppressed announcement' do
    event = push_event(commits: [push_commit('github-actions[bot]')])
    announcer, = announcer_for(event)

    allow(announcer).to receive(:log_mutable_send)
    announcer.check
    expect(announcer).not_to have_received(:log_mutable_send)
  end

  it 'passes only numbered filtered text to the send-and-log boundary' do
    event = push_event(commits: [push_commit('github-actions[bot]', message: 'Ignored'), push_commit('human')])
    announcer, channel = announcer_for(event)
    expected = [
      '[1/3] [web] sender pushed 1 announced commit (1 ignored) to master',
      '[2/3] web/master 111111111 Tester: Update site',
      '[3/3] https://github.com/vpsfreecz/web/compare/a...b'
    ].join("\n")

    allow(announcer).to receive(:log_mutable_send)
    allow(announcer).to receive(:p)
    announcer.check
    expect(announcer).to have_received(:log_mutable_send) do |target, text, type|
      expect(target).to equal(channel)
      expect(text.to_s).to eq(expected)
      expect(type).to eq(:notice)
    end
  end

  def ignored_channel
    { repositories: ['vpsfreecz/web'], ignored_users: ['github-actions[bot]'] }
  end

  def announcement(event, config: ignored_channel)
    described_class.announcement_in_channel(config, event)
  end

  def announcer_for(event)
    channel = instance_double(Cinch::Channel, name: '#vpsfree')
    announcer = described_class.allocate
    allow(announcer).to receive_messages(
      bot: instance_double(Cinch::Bot, channels: [channel]),
      config: { channels: { '#vpsfree' => ignored_channel } }
    )
    allow(described_class).to receive(:get_event).and_return(event)
    [announcer, channel]
  end

  def filtered_channel
    channels = described_class.normalize_channels(
      '#vpsfree' => {
        'repositories' => ['vpsfreecz/web'],
        'event_types' => %w[push issues pull_request],
        'default_branch_only' => true
      }
    )

    channels['#vpsfree']
  end

  def push_event(ref: 'refs/heads/master', repository: 'vpsfreecz/web', default_branch: 'master',
                 sender: 'sender', commits: [push_commit('human')], forced: false)
    event(
      'push',
      repository,
      default_branch,
      'ref' => ref,
      'before' => '0000000000000000000000000000000000000000',
      'after' => '1111111111111111111111111111111111111111',
      'created' => false,
      'deleted' => false,
      'forced' => forced,
      'compare' => 'https://github.com/vpsfreecz/web/compare/a...b',
      'commits' => commits,
      'sender' => user(sender)
    )
  end

  def push_commit(username, email: 'tester@example.org', distinct: true, message: 'Update site')
    {
      'id' => '1111111111111111111111111111111111111111',
      'message' => message,
      'distinct' => distinct,
      'author' => { 'name' => 'Tester', 'email' => email, 'username' => username },
      'committer' => { 'name' => 'Human', 'username' => 'human' }
    }
  end

  def issue_event(sender: 'sender')
    event(
      'issues',
      'vpsfreecz/web',
      'master',
      'action' => 'opened',
      'issue' => {
        'id' => 1,
        'number' => 42,
        'title' => 'Issue',
        'state' => 'open',
        'html_url' => 'https://github.com/vpsfreecz/web/issues/42',
        'user' => user('github-actions[bot]')
      },
      'sender' => user(sender)
    )
  end

  def pull_request_event(sender: 'sender')
    event(
      'pull_request',
      'vpsfreecz/web',
      'master',
      'action' => 'opened',
      'number' => 7,
      'pull_request' => {
        'id' => 2,
        'number' => 7,
        'title' => 'PR',
        'state' => 'open',
        'html_url' => 'https://github.com/vpsfreecz/web/pull/7',
        'user' => user('github-actions[bot]')
      },
      'sender' => user(sender)
    )
  end

  def create_event(repository: 'vpsfreecz/web', sender: 'sender')
    event(
      'create',
      repository,
      'master',
      'ref_type' => 'branch',
      'ref' => 'topic',
      'master_branch' => 'master',
      'description' => nil,
      'sender' => user(sender)
    )
  end

  def delete_event(sender: 'sender')
    event(
      'delete',
      'vpsfreecz/web',
      'master',
      'ref_type' => 'branch',
      'ref' => 'topic',
      'sender' => user(sender)
    )
  end

  def fork_event(sender: 'sender')
    event(
      'fork',
      'vpsfreecz/web',
      'master',
      'forkee' => repository('forker/web', 'master'),
      'sender' => user(sender)
    )
  end

  def event(type, repository_name, default_branch, attrs)
    VpsFree::Irc::Bot::GitHubWebHook::Event.parse(
      type,
      {
        'sender' => user('sender'),
        'repository' => repository(repository_name, default_branch),
        'pusher' => { 'name' => 'human' },
        'head_commit' => push_commit('human')
      }.merge(attrs)
    )
  end

  def repository(full_name, default_branch)
    owner_name, name = full_name.split('/', 2)

    {
      'id' => 100,
      'name' => name,
      'full_name' => full_name,
      'html_url' => "https://github.com/#{full_name}",
      'description' => 'Repository',
      'default_branch' => default_branch,
      'owner' => user(owner_name)
    }
  end

  def user(login)
    {
      'id' => 200,
      'login' => login,
      'html_url' => "https://github.com/#{login}"
    }
  end
end
