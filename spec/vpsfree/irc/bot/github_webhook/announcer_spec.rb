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

  def filtered_channel
    channels = described_class.normalize_channels(
      '#vpsfree' => {
        'repositories' => ['vpsfreecz/web'],
        'event_types' => %w(push issues pull_request),
        'default_branch_only' => true,
      }
    )

    channels['#vpsfree']
  end

  def push_event(repository: 'vpsfreecz/web', default_branch: 'master', ref:)
    event(
      'push',
      repository,
      default_branch,
      'ref' => ref,
      'before' => '0000000000000000000000000000000000000000',
      'after' => '1111111111111111111111111111111111111111',
      'created' => false,
      'deleted' => false,
      'forced' => false,
      'compare' => 'https://github.com/vpsfreecz/web/compare/a...b',
      'commits' => [
        {
          'id' => '1111111111111111111111111111111111111111',
          'message' => 'Update site',
          'distinct' => true,
          'author' => {
            'name' => 'Tester',
            'email' => 'tester@example.org',
          },
        },
      ]
    )
  end

  def issue_event
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
        'user' => user('reporter'),
      }
    )
  end

  def pull_request_event
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
        'user' => user('contributor'),
      }
    )
  end

  def create_event(repository: 'vpsfreecz/web')
    event(
      'create',
      repository,
      'master',
      'ref_type' => 'branch',
      'ref' => 'topic',
      'master_branch' => 'master',
      'description' => nil
    )
  end

  def delete_event
    event(
      'delete',
      'vpsfreecz/web',
      'master',
      'ref_type' => 'branch',
      'ref' => 'topic'
    )
  end

  def fork_event
    event(
      'fork',
      'vpsfreecz/web',
      'master',
      'forkee' => repository('forker/web', 'master')
    )
  end

  def event(type, repository_name, default_branch, attrs)
    VpsFree::Irc::Bot::GitHubWebHook::Event.parse(
      type,
      {
        'sender' => user('sender'),
        'repository' => repository(repository_name, default_branch),
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
      'owner' => user(owner_name),
    }
  end

  def user(login)
    {
      'id' => 200,
      'login' => login,
      'html_url' => "https://github.com/#{login}",
    }
  end
end
