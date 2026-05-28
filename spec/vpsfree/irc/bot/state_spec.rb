# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VpsFree::Irc::Bot::State do
  subject(:state) { described_class.send(:new) }

  it 'tracks active mute state' do
    muted_until = Time.now + 60

    state.mute(muted_until)

    expect(state).to be_muted
    expect(state.muted_until).to eq(muted_until)
  end

  it 'expires mute state that is in the past' do
    state.mute(Time.now - 1)

    expect(state).not_to be_muted
    expect(state.muted_until).to be_nil
  end

  it 'can be unmuted explicitly' do
    state.mute(Time.now + 60)
    state.unmute

    expect(state).not_to be_muted
  end
end
