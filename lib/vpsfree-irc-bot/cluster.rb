module VpsFree::Irc::Bot
  class Cluster
    include Cinch::Plugin
    include Command
    include Helpers
    include Api

    command :status do
      desc 'show cluster status'
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
  end
end
