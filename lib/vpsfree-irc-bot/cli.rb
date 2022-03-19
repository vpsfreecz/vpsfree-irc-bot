require 'optparse'
require 'yaml'

module VpsFree::Irc::Bot
  class Cli
    def self.run
      new.run
    end

    def initialize
      @opts = {
        state_dir: File.join(Dir.home, '.vpsfree-irc-bot'),
        archive_dst: '.',
        api_url: 'https://api.vpsfree.cz',
        config: [],
      }
    end

    def run
      usage = <<END
Usage: #{$0} [options] [-c CONFIG] | [<server> <channel...>]

Options:
END

      opt_parser = OptionParser.new do |opts|
        opts.banner = usage

        opts.on('-a', '--api URL', 'URL to the vpsAdmin API server') do |u|
          @opts[:api_url] = u
        end

        opts.on('-c', '--config FILE', 'Config file') do |f|
          @opts[:config] << f
        end

        opts.on('-u', '--archive-url URL', 'URL on which the web archive is available') do |u|
          @opts[:archive_url] = u
        end

        opts.on('-d', '--archive-dir DIR', 'Where to save the web archive on disk') do |d|
          @opts[:archive_dst] = d
        end

        opts.on('-n', '--nick NICK', "Set bot's nick (#{NAME})") do |n|
          @opts[:nick] = n
        end

        opts.on('-s', '--nickserv PASSWORD', 'Identify with nickserv') do |p|
          @opts[:nickserv] = p
        end

        opts.on('-v', '--version', 'Print version and exit') do
          puts VERSION
          exit
        end

        opts.on('-h', '--help', 'Show this help') do
          puts opts
          exit
        end
      end

      opt_parser.parse!

      if @opts[:config].empty? && ARGV.size < 2
        puts opt_parser
        exit(1)
      end

      label = host = channels = nil

      if @opts[:config].any?
        @opts[:config].each do |cfg_path|
          begin
            cfg = YAML.safe_load(File.read(cfg_path), symbolize_names: true)

            unless cfg.is_a?(::Hash)
              warn "Config must yield a hash"
              exit(1)
            end

            @opts = merge_config(@opts, cfg)

          rescue Errno::ENOENT
            warn "Config file '#{cfg_path}' does not exist"
            exit(1)

          rescue Psych::SyntaxError => e
            warn "Invalid config file: #{e.message}"
            exit(1)
          end

          if !@opts[:server]
            warn "Configure server"
            exit(1)

          elsif !@opts[:channels]
            warn "Configure channels"
            exit(1)
          end

          label = @opts[:server][:label]
          host = @opts[:server][:host]
          channels = @opts[:channels]
        end

      else
        label = host = ARGV[0]
        channels = ARGV[1..-1]
      end

      VpsFree::Irc::Bot.start(label, host, channels, @opts)
    end

    protected
    def merge_config(src, override)
      src.merge(override) do |k, old_v, new_v|
        if old_v.instance_of?(Hash)
          merge_config(old_v, new_v)
        else
          new_v
        end
      end
    end
  end
end
