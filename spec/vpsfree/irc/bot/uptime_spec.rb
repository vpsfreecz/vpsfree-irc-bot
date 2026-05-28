# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VpsFree::Irc::Bot::Uptime do
  subject(:uptime) { described_class.allocate }

  it 'formats durations shorter than one day' do
    expect(uptime.send(:format_duration, 3661)).to eq('01:01:01')
  end

  it 'formats durations with days' do
    expect(uptime.send(:format_duration, 90_061)).to eq('1 days, 01:01:01')
  end
end
