# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VpsFree::Irc::Bot::MultiLine do
  it 'prefixes each line with its position' do
    text = described_class.new("first\nsecond")

    expect(text.to_a).to eq([
                              '[1/2] first',
                              '[2/2] second'
                            ])
  end

  it 'renders the prefixed lines as a string' do
    text = described_class.new("first\nsecond")

    expect(text.to_s).to eq("[1/2] first\n[2/2] second")
  end
end
