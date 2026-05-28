# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VpsFree::Irc::Bot::Help do
  let(:bot) do
    instance_double(
      Cinch::Bot,
      channel_list: %w[#vpsfree #vpsadminos],
      nick: 'vpsfbot'
    )
  end

  it 'renders command summaries with private channel arguments when needed' do
    command = VpsFree::Irc::Bot::Command::Cmd.new(:seen)
    command.desc('find user')
    command.arg(:nick)

    help = described_class.new(bot, [command])
    help.commands(:private)

    expect(help).to include('seen <channel> <nick>')
    expect(help).to include('find user')
  end

  it 'renders detailed help with aliases and optional arguments' do
    command = VpsFree::Irc::Bot::Command::Cmd.new(:lastlog)
    command.desc('show last messages')
    command.aliases(:ll)
    command.arg(:n, required: false)

    help = described_class.new(bot, [command])
    help.command(:ll)

    expect(help).to include('Channel: !lastlog [n]')
    expect(help).to include('Private: lastlog <channel> [n]')
    expect(help).to include('Aliases:')
    expect(help).to include('    ll')
  end

  it 'raises for unknown commands' do
    help = described_class.new(bot, [])

    expect { help.command(:missing) }.to raise_error(ArgumentError, "command 'missing' not found")
  end
end
