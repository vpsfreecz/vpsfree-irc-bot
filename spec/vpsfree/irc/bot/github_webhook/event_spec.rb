# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VpsFree::Irc::Bot::GitHubWebHook::PushEvent do
  let(:before_sha) { '0123456789abcdef0123456789abcdef01234567' }
  let(:after_sha) { 'fedcba9876543210fedcba9876543210fedcba98' }
  let(:zero_sha) { '0000000000000000000000000000000000000000' }
  let(:repository_url) { 'https://github.com/vpsfreecz/web' }

  it 'links fast-forward events to the payload comparison' do
    event = push_event('commits' => [commit(distinct: false)])
    expected = message(
      '[web] sender fast-forwarded master from 012345678 to fedcba987',
      comparison_url
    )

    expect(event.to_s).to eq(expected)
  end

  it 'builds a comparison URL for fast-forward events without payload compare' do
    event = push_event(
      'compare' => nil,
      'commits' => [commit(distinct: false)]
    )
    expected = message(
      '[web] sender fast-forwarded master from 012345678 to fedcba987',
      comparison_url
    )

    expect(event.to_s).to eq(expected)
  end

  it 'links fast-forward events to the target commit when comparison is unsafe' do
    event = push_event(
      'before' => zero_sha,
      'compare' => nil,
      'commits' => [commit(distinct: false)]
    )
    expected = message(
      '[web] sender fast-forwarded master to fedcba987',
      "#{repository_url}/commit/#{after_sha}"
    )

    expect(event.to_s).to eq(expected)
  end

  it 'announces forced non-distinct updates as force-pushes' do
    event = push_event(
      'forced' => true,
      'commits' => [commit(distinct: false)]
    )
    expected = message(
      '[web] sender force-pushed master from 012345678 to fedcba987',
      comparison_url
    )

    expect(event.to_s).to eq(expected)
  end

  it 'keeps ordinary push announcements unchanged' do
    event = push_event
    expected = message(
      '[web] sender pushed 1 commit to master',
      'web/master fedcba987 Tester: Update site',
      comparison_url
    )

    expect(event.to_s).to eq(expected)
  end

  it 'keeps the legacy eleven-commit display' do
    event = push_event('commits' => Array.new(11) { |i| commit(message: "Change #{i}") })

    expect(event.to_s.lines.grep(/Tester: Change/).length).to eq(11)
    expect(event.to_s).not_to include('more commits')
  end

  [1, 10, 11, 12].each do |count|
    it "displays at most ten of #{count} retained commits with accurate counts" do
      ignored = Array.new(10) { commit(username: 'github-actions[bot]') }
      retained = Array.new(count) { |i| commit(username: 'human', message: "Human #{i}\nBody") }
      event = push_event('commits' => ignored + retained)
      text = event.filtered_to_s(event.commits.drop(10), ignored_count: 10)

      expect(text.lines.first).to eq(
        "[web] sender pushed #{count} announced #{count == 1 ? 'commit' : 'commits'} (10 ignored) to master\n"
      )
      expect(text.lines.grep(/Tester: Human/).length).to eq([count, 10].min)
      expect(text).to include('Human 0')
      expect(text).not_to include('Body')
      expect(text).to end_with(comparison_url)
      if count > 10
        expect(text).to include("...and #{count - 10} more commits")
        expect(text).not_to include('Human 10')
      else
        expect(text).not_to include('more commits')
      end
    end
  end

  it 'uses ordinary wording when the active filter excludes nothing' do
    event = push_event('commits' => [commit, commit(message: 'Second')])

    expect(event.filtered_to_s(event.commits, ignored_count: 0)).to eq(event.to_s)
  end

  %w[force-pushed fast-forwarded].each do |action|
    [0, 1].each do |ignored_count|
      it "renders retained details for #{action} with #{ignored_count} exclusions" do
        event = push_event(
          'forced' => action == 'force-pushed',
          'commits' => [commit(distinct: false), commit(distinct: false, message: 'Ignored')]
        )
        retained = event.commits.first(2 - ignored_count)
        text = event.filtered_to_s(retained, ignored_count: ignored_count)

        expect(text.lines.first).to eq("[web] sender #{action} master from 012345678 to fedcba987\n")
        expect(text).to include(ignored_count == 0 ? '[web] 2 commits' : '[web] 1 announced commit (1 ignored)')
        expect(text).to include('web/master fedcba987 Tester: Update site')
        expect(text.scan(comparison_url).length).to eq(1)
      end
    end
  end

  it 'keeps original push classification when the distinct commit is excluded' do
    event = push_event('commits' => [commit, commit(distinct: false, message: 'Retained')])
    text = event.filtered_to_s(event.commits.last(1), ignored_count: 1)

    expect(text).to start_with('[web] sender pushed 1 announced commit (1 ignored) to master')
    expect(text).not_to include('fast-forwarded')
  end

  it 'keeps ref-update fallback URLs in filtered rendering' do
    event = push_event('forced' => true, 'compare' => '', 'before' => zero_sha)
    text = event.filtered_to_s(event.commits, ignored_count: 0)

    expect(text).to start_with('[web] sender force-pushed master to fedcba987')
    expect(text).to end_with("#{repository_url}/commit/#{after_sha}")
  end

  it 'does not mutate the event or nested commits across repeated rendering' do
    event = push_event('commits' => [commit(username: 'human'), commit(username: 'github-actions[bot]')])
    original = Marshal.dump(event)
    event.commits.each do |c|
      c.author.freeze
      c.freeze
    end
    event.commits.freeze
    event.freeze

    twice = Array.new(2) { event.filtered_to_s(event.commits.first(1), ignored_count: 1) }

    expect(twice.first).to eq(twice.last)
    expect(Marshal.dump(event)).to eq(original)
    expect(event.to_s).to include('pushed 2 commits')
  end

  it 'preserves deleted-push and empty-creation gates' do
    expect(push_event('deleted' => true).announce?).to be(false)
    expect(push_event('created' => true, 'commits' => []).announce?).to be(false)
    expect(push_event('commits' => []).announce?).to be(true)
  end

  def push_event(attrs = {})
    VpsFree::Irc::Bot::GitHubWebHook::Event.parse(
      'push',
      {
        'sender' => user('sender'),
        'repository' => repository('vpsfreecz/web', 'master'),
        'ref' => 'refs/heads/master',
        'before' => before_sha,
        'after' => after_sha,
        'created' => false,
        'deleted' => false,
        'forced' => false,
        'compare' => comparison_url,
        'commits' => [commit]
      }.merge(attrs)
    )
  end

  def commit(id: after_sha, distinct: true, username: nil, message: 'Update site')
    {
      'id' => id,
      'message' => message,
      'distinct' => distinct,
      'author' => {
        'name' => 'Tester',
        'email' => 'tester@example.org',
        'username' => username
      }
    }
  end

  def comparison_url
    "#{repository_url}/compare/#{before_sha}...#{after_sha}"
  end

  def message(*lines)
    lines.join("\n")
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
  describe VpsFree::Irc::Bot::GitHubWebHook::Commit::Author do
    [
      ['github-actions[bot]', 'human@users.noreply.github.com', 'github-actions[bot]'],
      ['human', 'github-actions[bot]@users.noreply.github.com', 'human'],
      ['Human', nil, 'Human'],
      [nil, 'github-actions[bot]@users.noreply.github.com', 'github-actions[bot]'],
      ['', '41898282+github-actions[bot]@users.noreply.github.com', 'github-actions[bot]'],
      [nil, '123+human@users.noreply.github.com', 'human'],
      [false, 'github-actions[bot]@users.noreply.github.com', nil],
      [42, 'github-actions[bot]@users.noreply.github.com', nil],
      [nil, 'human@example.org', nil],
      [nil, 'x+github-actions[bot]@users.noreply.github.com', nil],
      [nil, '123+bot+alias@users.noreply.github.com', nil],
      [nil, '+bot@users.noreply.github.com', nil],
      [nil, '123+@users.noreply.github.com', nil],
      [nil, '@users.noreply.github.com', nil],
      [nil, 'bot@users.noreply.github.com.evil', nil],
      [nil, 'bot@USERS.NOREPLY.GITHUB.COM', nil],
      [nil, 'bot@@users.noreply.github.com', nil],
      [nil, "bot@users.noreply.github.com\n", nil],
      [nil, ' bot@users.noreply.github.com', nil],
      [nil, nil, nil],
      [nil, 42, nil]
    ].each do |username, email, expected|
      it "resolves username #{username.inspect} and email #{email.inspect} to #{expected.inspect}" do
        author = described_class.new('github-actions[bot]', email, username)

        expect(author.login).to eq(expected)
        expect(author.name).to eq('github-actions[bot]')
      end
    end
  end
end
