require 'json'
require 'sinatra/base'
require 'thread'

module VpsFree::Irc::Bot
  class DiscourseWebHook::Server
    def self.create(opts)
      Sinatra.new do
        set :server, :thin
        set :server_settings, {signals: false} # let sinatra trap exits
        set :bind, opts[:host]
        set :port, opts[:port]
        set :secret_token, opts[:secret]

        post '/discourse-webhook' do
          request.body.rewind
          payload_body = request.body.read
          verify_signature(payload_body)

          event = DiscourseWebHook::Event.parse(
            request.env['HTTP_X_DISCOURSE_INSTANCE'],
            request.env['HTTP_X_DISCOURSE_EVENT'],
            JSON.parse(payload_body)
          )
          DiscourseWebHook::Announcer.announce(event) if event && event.announce?

          200
        end

        not_found do
          'wrong address'
        end

        def verify_signature(payload_body)
          signature = 'sha256=' + OpenSSL::HMAC.hexdigest(
            OpenSSL::Digest.new('sha256'),
            settings.secret_token,
            payload_body
          )

          unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_DISCOURSE_EVENT_SIGNATURE'])
            return halt 400, 'Invalid signature'
          end
        end
      end
    end

    def self.start(opts)
      Thread.new do
        @server = create(opts)
        @server.run!
      end
    end
  end
end
