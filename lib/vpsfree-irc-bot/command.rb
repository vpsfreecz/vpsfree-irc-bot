module VpsFree::Irc::Bot
  module Command
    class Cmd
      Arg = Struct.new(:name, :required)

      attr_reader :name

      def initialize(name)
        @name = name
        @channel = true
        @args = []
      end

      def desc(v = nil)
        @desc = v
      end

      def channel(v)
        @channel = v
      end

      def arg(name, required: true)
        @args << Arg.new(name, required)
      end

      def exec(plugin, m, msg = nil)
        args = parse_args(m, msg || m.message)
        plugin.send(:"cmd_#{@name}", *args) if args
      end

      def parse_args(m, msg)
        args = [m]
        parts = msg.split
        parts.delete_at(0)

        if m.channel || !@channel
          args << m.channel

        elsif m.bot.channel_list.count == 1
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

        @args.each do |arg|
          break if parts.empty? && !arg.required

          if parts.empty?
            m.reply("missing required argument '#{arg.name}'")
            return
          end

          args << parts.first
          parts.delete_at(0)
        end

        args
      end

      def help(mode, require_channel)
        sig = [(mode == :channel ? '!' : '') + @name.to_s]
        sig << '<channel>' if require_channel && mode == :private && @channel

        @args.each do |arg|
          if arg.required
            sig << '<' + arg.name + '>'

          else
            sig << '[' + arg.name.to_s + ']'
          end
        end
        
        "#{sig.join(' ').ljust(30)} #{@desc}"
      end
    end

    module ClassMethods
      def command(name, &block)
        cmd = Cmd.new(name)
        cmd.instance_exec(&block)

        method = :"exec_#{cmd}"
        channel_method = :"check_channel_#{name}"
        
        listen_to :channel, method: channel_method
        match /^!#{name}/, react_on: :channel, use_prefix: false, method: method
        match /^!?#{name}/, react_on: :private, use_prefix: false, method: method

        define_method(method) do |m|
          cmd.exec(self, m)
        end

        define_method(channel_method) do |m|
          if /^#{m.bot.nick}(:|,|\s)\s*(!?#{name}(\s|$)[^$]*)/ =~ m.message
            cmd.exec(self, m, $2)
          end
        end

        Command.register(cmd)
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
