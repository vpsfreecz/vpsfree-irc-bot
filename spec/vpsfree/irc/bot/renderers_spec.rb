# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VpsFree::Irc::Bot::TemplateLogger::Renderer do
  subject(:renderer) do
    described_class.allocate.tap do |instance|
      instance.instance_variable_set(:@coder, HTMLEntities.new)
    end
  end

  it 'escapes YAML single quotes' do
    expect(renderer.yml_escape("it's fine")).to eq("it''s fine")
  end

  it 'escapes basic HTML entities' do
    expect(renderer.encode('<message>')).to eq('&lt;message&gt;')
  end

  it 'can escape hash characters for fragment-safe links' do
    expect(renderer.encode('#vpsfree', hashtag: true)).to eq('%23vpsfree')
  end
end
