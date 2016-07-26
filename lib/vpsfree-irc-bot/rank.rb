require 'yaml'

module VpsFree::Irc::Bot
  class Rank
    include Cinch::Plugin
    include Command

    listen_to :channel, method: :channel

    command :rank do
      desc 'show your rank'
    end
    
    command :top do
      arg :n, required: false
      desc "show top N users"
    end

    UserStorage.defaults messages: 0

    def channel(m)
      UserStorage.instance.set(m.channel, m.user) do |data|
        data[:messages] += 1
        true
      end
    end

    def cmd_rank(m, channel)
      UserStorage.instance.get_all(channel) do |users|
        if users.empty?
          m.reply('You have no rank yet.')
          return
        end

        sorted = sort(users)
        rank = sorted.index { |name, _| name == m.user.nick }
        
        m.reply(
            "Your rank is #{rank+1} of #{users.size} users "+
            "with #{sorted[rank][1][:messages]} messages"
        )
      end
    end

    def cmd_top(m, channel, raw_n = nil)
      n = raw_n ? raw_n.to_i : 5
      n = 1 if n < 1
      n = 10 if n > 10

      UserStorage.instance.get_all(channel.to_s) do |users|
        if users.size == 0
          m.reply("No users to rank yet.")
          return
        end

        i = 1

        sort(users)[0..n-1].each do |u, stats|
          m.reply("#{i.to_s.rjust(2)}. #{u} (#{stats[:messages]} messages)")
          i += 1
        end
      end
    end

    protected
    def sort(users)
      users.sort { |a, b| a[1][:messages] <=> b[1][:messages] }.reverse!
    end
  end
end
