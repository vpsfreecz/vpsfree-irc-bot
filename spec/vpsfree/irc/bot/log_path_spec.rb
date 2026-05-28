# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VpsFree::Irc::Bot::LogPath do
  let(:time) { Time.new(2026, 5, 28, 12, 0, 0) }

  it 'builds local paths for server, channel and day' do
    path = described_class.new('html')

    expect(path.as_local(server: 'libera', channel: '#vpsfree', time: time))
      .to eq('libera/#vpsfree/2026/05/28.html')
  end

  it 'escapes URL path segments' do
    path = described_class.new('html')

    expect(path.as_url(server: 'libera chat', channel: '#vps free', time: time))
      .to eq('libera+chat/%23vps+free/2026/05/28.html')
  end

  it 'keeps resolved paths independent from the original path' do
    path = described_class.new('yml')
    resolved = path.resolve(server: 'libera', channel: '#vpsfree')

    expect(resolved.as_local(time: time)).to eq('libera/#vpsfree/2026/05/28.yml')
    expect { path.as_local(time: time) }.to raise_error(ArgumentError, 'missing server')
  end
end
