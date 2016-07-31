require 'thread'
require 'haveapi/client'

module VpsFree::Irc::Bot
  class Cluster
    include Cinch::Plugin
    include Command
    include Helpers
    
    listen_to :connect, method: :connect

    command :status do
      desc 'show cluster status'
    end

    def initialize(*args)
      super
      @mutex = Mutex.new
    end

    def connect(m)
      @mutex.synchronize do
        @api = ::HaveAPI::Client::Client.new(
            m.bot.config.api_url,
            identity: "vpsfree-irc-bot v#{VERSION}"
        )
        @api.setup
      end
    end
    
    def cmd_status(m, channel)
      client do |api|
        nodes = api.node.public_status

        # Have to access status via attributes, because status is also a subresource
        down = nodes.count { |n| !n.attributes[:status] && n.maintenance_lock == 'no' }
        maintenance = nodes.count { |n| n.maintenance_lock != 'no' }
        online = nodes.size - down - maintenance

        reply(m, "#{online} nodes online, #{maintenance} under maintenance, #{down} down")

        if maintenance > 0
          reply(
              m,
              "Under maintenance: "+
              nodes.select { |n|
                n.maintenance_lock != 'no'
              }.map { |n| n.name }.join(', ')
          )
        end
        
        if down > 0
          reply(
              m,
              "Down: "+
              nodes.select { |n|
                !n.attributes[:status] && n.maintenance_lock == 'no'
              }.map { |n| n.name }.join(', ')
          )
        end
      end
    end

    protected
    def client
      @mutex.synchronize { yield(@api) }
    end
  end
end
