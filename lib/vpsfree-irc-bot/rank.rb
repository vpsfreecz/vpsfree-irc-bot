require 'yaml'

module VpsFree::Irc::Bot
  class Rank
    include Cinch::Plugin
    include Command

    listen_to :channel, method: :channel_message
    listen_to :channel, method: :channel_karma

    command :rank do
      desc 'show your rank'
    end
    
    command :top do
      arg :n, required: false
      desc "show top N users"
    end

    UserStorage.defaults(
        messages: 0,
        karma: {
            today: {given: 0, taken: 0, received: 0},
            total: {given: 0, taken: 0, received: 0},
        },
    )

    def initialize(*_)
      super

      DayChange.on do
        UserStorage.instance.set_all do |channels|
          channels.each do |name, users|
            users.each do |nick, data|
              data[:karma] ||= {}
              data[:karma][:today] = {given: 0, taken: 0, received: 0}
            end
          end

          true
        end
      end
    end

    def channel_message(m)
      UserStorage.instance.set(m.channel, m.user) do |data|
        data[:messages] += 1
        true
      end
    end

    def channel_karma(m)
      m.channel.users.each_key do |user|
        safe_nick = Regexp.escape(user.nick)

        if /^#{safe_nick}[\s|:|,]\s*(\+\d+|-\d+)/ =~ m.message
          # karma +- n
          n = $1.to_i

          n = -10 if n < -10
          n = 10 if n > 10

          update_karma(m.target, m.channel, m.user, user, n)
          break

        elsif /^#{safe_nick}(\+\+|\-\-)/ =~ m.message
          # karma +- 1
          update_karma(m.target, m.channel, m.user, user, $1 == '++' ? 1 : -1)
          break
        end
      end
    end

    def cmd_rank(m, channel)
      UserStorage.instance.get_channel(channel) do |users|
        if users.empty?
          m.reply('You have no rank yet.')
          return
        end

        sorted = sort(users)
        rank = sorted.index { |name, _| name == m.user.nick }
        
        m.reply(
            "Your rank is #{rank+1} of #{users.size} users "+
            "with karma #{sorted[rank][1][:karma][:total][:received]} and "+
            "#{sorted[rank][1][:messages]} messages"
        )
      end
    end

    def cmd_top(m, channel, raw_n = nil)
      n = raw_n ? raw_n.to_i : 5
      n = 1 if n < 1
      n = 10 if n > 10

      UserStorage.instance.get_channel(channel.to_s) do |users|
        if users.size == 0
          m.reply("No users to rank yet.")
          return
        end

        i = 1

        sort(users)[0..n-1].each do |u, stats|
          m.reply(
              "#{i.to_s.rjust(2)}. #{u} "+
              "(karma #{stats[:karma][:total][:received]}, #{stats[:messages]} messages)"
          )
          i += 1
        end
      end
    end

    protected
    # @param target [Cinch::Target]
    # @param channel [Cinch::Channel]
    # @param who [Cinch::User] who gives karma
    # @param whom [Cinch::User] who receives karma
    # @param n [Integer] how much karma
    def update_karma(target, channel, who, whom, n)
      if who == whom
        target.send("You can't change your own karma bro")
        return
      end
      
      UserStorage.instance.synchronize do |storage|
        catch(:break) do
          # Check the giver
          storage.get(channel, who) do |data|
            if n > 0 && (n + data[:karma][:today][:given]) > 10
              target.send("Cannot give more than 10 karma points per day")
              throw(:break)

            elsif n < 0 && (n + data[:karma][:today][:taken]) < -10
              target.send("Cannot take more than 10 karma points per day")
              throw(:break)
            end
          end
          
          # Check the receiver
          storage.get(channel, whom) do |data|
            received = data[:karma][:today][:received]

            if n > 0 && (n + received) > 50
              target.send("Cannot receive more than 50 karma points per day")
              throw(:break)

            elsif n < 0 && received < 0 && (n + received) < -50
              target.send("Cannot lose more than 50 karma points per day")
              throw(:break)
            end
          end

          # Assign karma
          storage.set(channel, who) do |data|
            if n > 0
              data[:karma][:total][:given] += n
              data[:karma][:today][:given] += n

            else
              data[:karma][:total][:taken] += n
              data[:karma][:today][:taken] += n
            end

            true
          end

          storage.set(channel, whom) do |data|
            data[:karma][:total][:received] += n
            data[:karma][:today][:received] += n
            true
          end
        end
      end
    end

    def sort(users)
      users.sort do |a, b|
        a_rcv = a[1][:karma][:total][:received]
        b_rcv = b[1][:karma][:total][:received]

        if a_rcv == b_rcv
          a[1][:messages] <=> b[1][:messages]

        else
          a_rcv <=> b_rcv
        end
      end.reverse!
    end
  end
end
