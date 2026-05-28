# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VpsFree::Irc::Bot::Command::Cmd do
  it 'passes the current channel to channel commands' do
    command = described_class.new(:seen)
    command.arg(:nick)
    channel = irc_channel('#vpsfree')
    message = command_message(channel: channel, text: '!seen alice')

    expect(command.parse_args(message, message.message)).to eq([message, channel, 'alice'])
  end

  it 'uses the sole joined channel for private channel commands' do
    command = described_class.new(:seen)
    channel = irc_channel('#vpsfree')
    message = command_message(channel: nil, channels: [channel], text: 'seen')

    expect(command.parse_args(message, message.message)).to eq([message, channel])
  end

  it 'requires an explicit channel for private channel commands when multiple channels are joined' do
    command = described_class.new(:seen)
    message = command_message(channel: nil, channels: [irc_channel('#a'), irc_channel('#b')], text: 'seen')

    expect(command.parse_args(message, message.message)).to be_nil
    expect(message).to have_received(:reply).with('missing channel name')
  end

  it 'validates private command channel names' do
    command = described_class.new(:seen)
    message = command_message(
      channel: nil,
      channels: [irc_channel('#vpsfree'), irc_channel('#vpsadminos')],
      text: 'seen #unknown'
    )

    expect(command.parse_args(message, message.message)).to be_nil
    expect(message).to have_received(:reply).with("invalid channel '#unknown'")
  end

  it 'reports missing required arguments' do
    command = described_class.new(:seen)
    command.arg(:nick)
    channel = irc_channel('#vpsfree')
    message = command_message(channel: channel, text: '!seen')

    expect(command.parse_args(message, message.message)).to be_nil
    expect(message).to have_received(:reply).with("missing required argument 'nick'")
  end

  it 'omits optional arguments when they are not present' do
    command = described_class.new(:lastlog)
    command.arg(:n, required: false)
    channel = irc_channel('#vpsfree')
    message = command_message(channel: channel, text: '!lastlog')

    expect(command.parse_args(message, message.message)).to eq([message, channel])
  end

  def irc_channel(name)
    instance_double(Cinch::Channel, to_s: name)
  end

  def command_message(channel:, text:, channels: [channel])
    channel_list_class = Class.new(Array) do
      def find(name)
        detect { |channel| channel.to_s == name }
      end
    end
    channel_list = channel_list_class.new(channels.compact)
    bot = instance_double(Cinch::Bot, channel_list: channel_list)

    instance_double(
      Cinch::Message,
      bot: bot,
      channel: channel,
      message: text,
      reply: nil
    )
  end
end
