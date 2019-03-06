require 'json'
require 'sinatra'
require 'thread'

module VpsFree::Irc::Bot
  class GitHubWebHook::Server
    def self.create(opts)
      Sinatra.new do
        set :server, :thin
        set :server_settings, {signals: false} # let sinatra trap exits
        set :bind, opts[:host]
        set :port, opts[:port]
        set :secret_token, opts[:secret]

        post '/gh-webhook' do
          request.body.rewind
          payload_body = request.body.read
          verify_signature(payload_body)

          event = GitHubWebHook::Event.parse(
            request.env['HTTP_X_GITHUB_EVENT'],
            JSON.parse(payload_body)
          )
          GitHubWebHook::Announcer.announce(event) if event && event.announce?

          200
        end

        not_found do
          'wrong address'
        end

        def verify_signature(payload_body)
          signature = 'sha1=' + OpenSSL::HMAC.hexdigest(
            OpenSSL::Digest.new('sha1'),
            settings.secret_token,
            payload_body
          )

          unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
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
