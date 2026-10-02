require 'cinch'
require 'vpsfree-irc-bot/helpers'

module VpsFree::Irc::Bot
  class GitHubWebHook::Announcer
    include Cinch::Plugin
    include Helpers

    class ChannelConfig
      attr_reader :repositories, :event_types, :default_branch_only, :ignored_users

      def initialize(repositories:, event_types: nil, default_branch_only: false, ignored_users: [])
        @repositories = Array(repositories).map(&:to_s)
        @event_types = event_types && Array(event_types).map(&:to_s)
        @default_branch_only = default_branch_only
        @ignored_users = Array(ignored_users).map(&:to_s)
      end

      def announce?(event)
        return false if event.repository.nil?
        return false unless repositories.include?(event.repository.full_name)
        return false if event_types && !event_types.include?(event.type)

        if default_branch_only && event.type == 'push' && !event.default_branch?
          return false
        end

        true
      end

      def announcement(event)
        return nil unless announce?(event)
        return event.to_s if ignored_users.empty?

        if event.type == 'push' && !event.commits.empty?
          retained = event.commits.reject { |commit| ignored_users.include?(commit.author.login) }
          return nil if retained.empty?

          return event.filtered_to_s(retained, ignored_count: event.commits.length - retained.length)
        end

        event.to_s unless ignored_users.include?(event.sender.login)
      end
    end

    set required_options: %i[channels]
    timer 1, method: :check, threaded: false

    class << self
      def normalize_channels(channels)
        channels.each_with_object({}) do |(channel, opts), ret|
          ret[channel.to_s] = normalize_channel_config(opts)
        end
      end

      def normalize_channel_config(opts)
        return opts if opts.is_a?(ChannelConfig)

        if opts.is_a?(Array)
          return ChannelConfig.new(repositories: opts)
        end

        unless opts.is_a?(Hash)
          raise ArgumentError, "invalid GitHub channel configuration: #{opts.inspect}"
        end

        repositories = config_value(opts, :repositories) || []
        event_types = config_value(opts, :event_types)
        default_branch_only = config_value(opts, :default_branch_only)

        ChannelConfig.new(
          repositories: repositories,
          event_types: event_types,
          default_branch_only: !!default_branch_only,
          ignored_users: config_value(opts, :ignored_users)
        )
      end

      def announce_in_channel?(channel_config, event)
        normalize_channel_config(channel_config).announce?(event)
      end

      def announcement_in_channel(channel_config, event)
        normalize_channel_config(channel_config).announcement(event)
      end

      # @param event [GitHubWebHook::Event]
      def announce(event)
        queue << event
      end

      # @return [GitHubWebHook::Event]
      def get_event
        queue.pop
      end

      def queue
        @queue ||= ::Queue.new
      end

      protected

      def config_value(config, key)
        return config[key] if config.has_key?(key)
        return config[key.to_s] if config.has_key?(key.to_s)

        config[key.to_sym] if config.has_key?(key.to_sym)
      end
    end

    def check
      event = self.class.get_event

      bot.channels.each do |channel|
        channel_config = config[:channels][channel.name]
        next if channel_config.nil?

        announcement = self.class.announcement_in_channel(channel_config, event)
        next if announcement.nil?

        log_mutable_send(
          channel,
          MultiLine.new(announcement),
          :notice
        )

        p event
      end
    end
  end
end
