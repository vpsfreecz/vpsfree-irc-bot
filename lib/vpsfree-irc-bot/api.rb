require 'thread'
require 'haveapi/client'

module VpsFree::Irc::Bot
  module Api
    def api_setup
      @api_mutex ||= Mutex.new

      @api = ::HaveAPI::Client::Client.new(
        config[:api_url],
        identity: "vpsfree-irc-bot v#{VERSION}"
      )

      begin
        @api.setup
        @api_setup = true
      rescue => e
        warn "Exception during API setup: #{e.message} (#{e.class})"
        Timer(15, shots: 1, threaded: false) { api_setup }
        return
      end

      post_api_setup if respond_to?(:post_api_setup)
    end

    def client
      fail 'API not set up yet' unless @api_setup
      @api_mutex.synchronize { yield(@api) }
    end

    def api_setup?
      @api_setup
    end

    def self.included(klass)
      klass.set(required_options: %i(api_url))
      klass.timer(0, method: :api_setup, shots: 1, threaded: false)
    end
  end
end
