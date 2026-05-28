module VpsFree::Irc::Bot
  module Command
    class Cmd
      Arg = Struct.new(:name, :required)

      attr_reader :name, :args

      def initialize(name)
        @name = name
        @channel = true
        @help = true
        @args = []
        @aliases = []
      end

      def names
        [@name] + @aliases
      end

      def desc(v = nil)
        if v.nil?
          @desc
        else
          @desc = v
        end
      end

      def channel(v = nil)
        if v.nil?
          @channel
        else
          @channel = v
        end
      end

      def help(v = nil)
        if v.nil?
          @help
        else
          @help = v
        end
      end

      def arg(name, required: true)
        @args << Arg.new(name, required)
      end

      def aliases(*args)
        if args.empty?
          @aliases
        else
          @aliases.concat(args)
        end
      end

      def exec(plugin, m, msg = nil)
        Command::Counter.increment
        args = parse_args(m, msg || m.message)
        return unless args

        unless VpsFree::Irc::Bot::EasterEggs.is_time? \
           && VpsFree::Irc::Bot::EasterEggs.cmd_exec(@name, *args)
          plugin.send(:"cmd_#{@name}", *args)
        end
      end

      def parse_args(m, msg)
        args = [m]
        parts = msg.split
        parts.delete_at(0)

        if m.channel || !@channel
          args << m.channel

        elsif m.bot.channel_list.one?
          args << m.bot.channel_list.first

        else
          unless parts[0]
            m.reply('missing channel name')
            return
          end

          chan = m.bot.channel_list.find(parts[0])

          unless chan
            m.reply("invalid channel '#{parts[0]}'")
            return
          end

          parts.delete_at(0)
          args << chan
        end

        missing_arg = nil

        @args.each do |arg|
          break if parts.empty? && !arg.required

          if parts.empty?
            missing_arg = arg
            break
          end

          args << parts.first
          parts.delete_at(0)
        end

        if missing_arg
          m.reply("missing required argument '#{missing_arg.name}'")
          return
        end

        args
      end
    end

    module ClassMethods
      def command(name, &)
        cmd = Cmd.new(name)
        cmd.instance_exec(&)

        method = :"exec_#{cmd}"
        channel_method = :"check_channel_#{name}"

        listen_to :channel, method: channel_method

        cmd.names.each do |n|
          match(/^!#{Regexp.escape(n)}(\s|$)/, react_on: :channel, use_prefix: false, method: method)
          match(/^!?#{Regexp.escape(n)}(\s|$)/, react_on: :private, use_prefix: false, method: method)
        end

        define_method(method) do |m|
          cmd.exec(self, m)
        end

        define_method(channel_method) do |m|
          cmd.names.each do |n|
            if /^#{m.bot.nick}(:|,|\s)\s*(!?#{Regexp.escape(n)}(\s|$)[^$]*)/ =~ m.message
              cmd.exec(self, m, ::Regexp.last_match(2))
              next
            end
          end
        end

        Command.register(cmd)
      end
    end

    module Counter
      def self.increment
        @counter ||= 0
        @counter += 1
      end

      def self.count
        @counter
      end
    end

    def self.register(cmd)
      @commands ||= []
      @commands << cmd
    end

    def self.commands
      @commands
    end

    def self.included(klass)
      klass.send(:extend, ClassMethods)
    end
  end
end
