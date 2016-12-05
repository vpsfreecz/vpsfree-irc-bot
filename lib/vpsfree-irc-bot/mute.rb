require 'date'
require 'chronic_duration'

module VpsFree::Irc::Bot
  class Mute
    include Cinch::Plugin
    include Command
    include Helpers

    MAX_DURATION = 6*60*60

    command :mute do
      desc 'mute the bot'
      arg :type, required: false
      arg :value, required: false
    end

    command :unmute do
      desc 'unmute the bot'
    end

    command :'muted?' do
      desc 'query the mute status'
    end

    def cmd_mute(m, channel, type = nil, value = nil)
      mute_until = nil
      now = Time.now

      if type && value.nil?
        reply(m, "Please specify both arguments: [<for/to> <duration/time>]")
        return
      end

      case type
      when 'to' # value is a date
        begin
          mute_until = DateTime.iso8601(value).to_time

        rescue ArgumentError => e
          reply(m, e.message)
          return
        end

      when 'for' # value is a duration
        n = ChronicDuration.parse(value)

        unless n
          reply(m, "Nope, I cannot parse that one. Try again?")
          return
        end

        mute_until = now + n

      when nil
        mute_until = now + 5*60

      else
        reply(m, "Invalid argument type: '#{type}'. Must be one of: for, to")
        return
      end

      if mute_until < now
        reply(m, "Cannot mute into the past...")
        return

      elsif (mute_until - now) > MAX_DURATION
        mute_until = now + MAX_DURATION
      end

      State.get.mute(mute_until)
      reply_action(m, "is muted until #{mute_until.iso8601}")
    end

    def cmd_unmute(m, channel)
      State.get.unmute
      reply_action(m, "is free again!")
    end

    def cmd_muted?(m, channel)
      muted = State.get.muted_until

      reply_action(
          m,
          muted ? "is muted until #{muted.iso8601}" : 'is not muted'
      )
    end
  end
end
