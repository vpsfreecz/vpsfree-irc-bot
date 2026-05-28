# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VpsFree::Irc::Bot::DiscourseWebHook::Event do
  it 'parses topic-created events' do
    event = described_class.parse(
      'https://discourse.example',
      'topic_created',
      'topic' => {
        'slug' => 'welcome',
        'id' => 42,
        'title' => 'Welcome',
        'created_by' => { 'username' => 'alice' }
      }
    )

    expect(event.to_s).to eq(
      '[Discourse] alice created topic Welcome: https://discourse.example/t/welcome/42'
    )
  end

  it 'parses post-created events' do
    event = described_class.parse(
      'https://discourse.example',
      'post_created',
      'post' => {
        'topic_slug' => 'welcome',
        'topic_id' => 42,
        'post_number' => 3,
        'topic_title' => 'Welcome',
        'username' => 'bob'
      }
    )

    expect(event.to_s).to eq(
      '[Discourse] bob posted to Welcome: https://discourse.example/t/welcome/42/3'
    )
  end

  it 'ignores unsupported events' do
    expect(described_class.parse('https://discourse.example', 'unknown', {})).to be_nil
  end
end
