module VpsFree::Irc::Bot
  class Help < String
    def initialize(bot, commands)
      super()
      @bot = bot
      @cmds = commands.sort { |a, b| a.name <=> b.name }
    end

    def commands(mode)
      require_channel = @bot.channel_list.count > 1

      @cmds.each do |cmd|
        self << " "*4 + cmd_line(cmd, mode, require_channel) + "\n"
      end
    end

    def cmd_line(cmd, mode, require_channel)
      name = (mode == :channel ? '!' : '') + cmd.name.to_s
      sig = cmd_args(cmd, mode, require_channel)
      "#{name} #{sig.join(' ')}".ljust(30) + cmd.desc
    end

    def cmd_args(cmd, mode, require_channel)
      sig = []
      sig << '<channel>' if require_channel && mode == :private && cmd.channel

      cmd.args.each do |arg|
        if arg.required
          sig << '<' + arg.name.to_s + '>'

        else
          sig << '[' + arg.name.to_s + ']'
        end
      end
      
      sig
    end

    def command(name)
      cmd = @cmds.detect { |c| c.names.include?(name) }
      raise ArgumentError, "command '#{name}' not found" if cmd.nil?

      chan_sig = cmd_args(cmd, :channel, false).join(' ')
      priv_sig = cmd_args(cmd, :private, @bot.channel_list.count > 1).join(' ')

      self << <<END
Syntax:
  Channel: !#{cmd.name} #{chan_sig}
           #{@bot.nick}: #{cmd.name} #{chan_sig}
  Private: #{cmd.name} #{priv_sig}

END
      
    if cmd.aliases.any?
      self << "Aliases:\n#{cmd.aliases.map { |v| "    #{v}" }.join("\n")}\n\n"
    end

    self << "Description:\n    #{cmd.desc}"
    end

    def to_s
      MultiLine.new(self).to_s
    end
  end
end
