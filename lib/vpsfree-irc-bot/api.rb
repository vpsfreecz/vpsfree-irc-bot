require 'thread'
require 'haveapi/client'

module VpsFree::Irc::Bot
  module Api
    def api_setup
      @api_mutex = Mutex.new
      @api = ::HaveAPI::Client::Client.new(
        config[:api_url],
        identity: "vpsfree-irc-bot v#{VERSION}"
      )
      @api.setup
      post_api_setup if respond_to?(:post_api_setup)
    end

    def client
      @api_mutex.synchronize { yield(@api) }
    end

    def self.included(klass)
      klass.set(required_options: %i(api_url))
      klass.timer(0, method: :api_setup, shots: 1, threaded: false)
    end
  end
end
