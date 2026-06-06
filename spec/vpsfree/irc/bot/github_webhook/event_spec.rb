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

  def commit(id: after_sha, distinct: true)
    {
      'id' => id,
      'message' => 'Update site',
      'distinct' => distinct,
      'author' => {
        'name' => 'Tester',
        'email' => 'tester@example.org'
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
end
