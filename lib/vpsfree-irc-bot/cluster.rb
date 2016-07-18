require 'thread'
require 'haveapi/client'

module VpsFree::Irc::Bot
  class Cluster
    include Cinch::Plugin
    include Command
    
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

        if nodes.detect { |n| !n.status || n.maintenance_lock != 'no' }
          # At least one node down or in maintenance
          down = nodes.count { |n| !n.status && n.maintenance_lock == 'no' }
          maintenance = nodes.count { |n| n.maintenance_lock != 'no' }
          online = nodes.size - down - maintenance

          m.reply("#{online} nodes online, #{maintenance} under maintenance, #{down} down")

          nodes.each do |n|
            if n.status && n.maintenance_lock == 'no'
              next

            elsif n.maintenance_lock != 'no'
              m.reply("#{n.name} is under maintenance: #{n.maintenance_lock_reason}")

            else
              m.reply("#{n.name} is down")
            end
          end
          
        else  # all up
          m.reply('All nodes are online')
        end
      end
    end

    protected
    def client
      @mutex.synchronize { yield(@api) }
    end
  end
end
