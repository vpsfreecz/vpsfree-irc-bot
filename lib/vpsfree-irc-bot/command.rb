#require 'struct'

module VpsFree::Irc::Bot
  module Command
    class Cmd
      Arg = Struct.new(:name, :required)

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

      def exec(plugin, m)
        args = parse_args(m)
        plugin.send(:"cmd_#{@name}", *args) if args
      end

      def parse_args(m)
        args = [m]
        parts = m.params[1].split
        parts.delete_at(0)

        if m.channel || !@channel
          args << m.channel

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

      def help(mode)
        sig = [(mode == :channel ? '!' : '') + @name.to_s]
        sig << '<channel>' if mode == :private && @channel

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

        match /^!#{name}/, react_on: :channel, use_prefix: false, method: method
        match /^!?#{name}/, react_on: :private, use_prefix: false, method: method

        define_method(method) { |m| cmd.exec(self, m) }
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
