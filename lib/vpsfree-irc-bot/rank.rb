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

    def initialize(*_)
      super
      @channel_users = {}
      load_ranks
      persistence
    end

    def channel(m)
      synchronize(:ranks) do
        @channel_users[m.channel.to_s] ||= {}
        @channel_users[m.channel.to_s][m.user.nick] ||= {messages: 0}
        @channel_users[m.channel.to_s][m.user.nick][:messages] += 1
      end
    end

    def cmd_rank(m, channel)
      synchronize(:ranks) do
        if @channel_users[channel.to_s].nil? \
          || @channel_users[channel.to_s][m.user.nick].nil?
          m.reply('You have no rank yet.')
          return
        end

        sorted = sorted_users(channel.to_s)
        rank = sorted.index { |name, _| name == m.user.nick }
        
        m.reply(
            "Your rank is #{rank+1} of #{@channel_users[channel.to_s].size} users "+
            "with #{sorted[rank][1][:messages]} messages"
        )
      end
    end

    def cmd_top(m, channel, raw_n = nil)
      n = raw_n ? raw_n.to_i : 5
      n = 1 if n < 1
      n = 10 if n > 10

      synchronize(:ranks) do
        users = @channel_users[channel.to_s]
        
        if users.nil? || users.size == 0
          m.reply("No users to rank yet.")
          return
        end

        i = 1

        sorted_users(channel.to_s)[0..n-1].each do |u, stats|
          m.reply("#{i.to_s.rjust(2)}. #{u} (#{stats[:messages]} messages)")
          i += 1
        end
      end
    end

    protected
    # @param channel [String]
    def sorted_users(channel)
      @channel_users[channel].sort { |a, b| a[1][:messages] <=> b[1][:messages] }.reverse!
    end

    def load_ranks
      return unless Dir.exists?(save_dir)

      Dir.glob(File.join(save_dir, '*.yml')) do |f|
        @channel_users[ File.basename(f).split('.')[0] ] = YAML.load(File.read(f))
      end
    end

    def persistence
      FileUtils.mkpath(save_dir)

      Thread.new do
        loop do
          sleep(15)

          synchronize(:ranks) do
            @channel_users.each do |name, users|
              file = File.join(save_dir, "#{name}.yml")

              File.open("#{file}.new", 'w') do |f|
                f.write(YAML.dump(users))
              end

              FileUtils.mv("#{file}.new", file)
            end
          end
        end
      end
    end

    def save_dir
      File.join(Dir.home, '.vpsfree-irc-bot', 'ranks')
    end
  end
end
