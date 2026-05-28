# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe VpsFree::Irc::Bot::FileStorage do
  let(:state_dir) { Dir.mktmpdir }

  after do
    FileUtils.remove_entry(state_dir)
  end

  it 'persists file-backed key/value data as YAML' do
    storage_class = Class.new(described_class) do
      def persistence; end

      public :save
    end

    storage = storage_class.send(:new, state_dir, 'libera', :karma)
    storage[:alice] = { 'points' => 2 }
    storage.save

    loaded = storage_class.send(:new, state_dir, 'libera', :karma)
    expect(loaded[:alice]).to eq('points' => 2)
  end

  it 'merges user defaults with saved channel data' do
    storage_class = Class.new(VpsFree::Irc::Bot::UserStorage) do
      def persistence; end
    end
    storage_class.defaults(messages: 0, karma: { received: 0 })

    storage = storage_class.send(:new, state_dir, 'libera')
    channel = instance_double(Cinch::Channel, to_s: '#vpsfree')
    user = instance_double(Cinch::User, nick: 'alice')

    storage.set(channel, user) do |data|
      data[:messages] += 1
      true
    end

    storage.get(channel, user) do |data|
      expect(data).to eq(messages: 1, karma: { received: 0 })
    end
  end
end
