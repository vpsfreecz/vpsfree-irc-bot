require 'optparse'
require 'yaml'

module VpsFree::Irc::Bot
  class Cli
    def self.run
      new.run
    end

    def initialize
      @opts = {
        archive_dst: '.',
        api_url: 'https://api.vpsfree.cz',
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
          @opts[:config] = f
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

      if !@opts[:config] && ARGV.size < 2
        puts opt_parser
        exit(1)
      end

      if @opts[:config]
        begin
          cfg = YAML.load(File.read(@opts[:config]))

          unless cfg.is_a?(::Hash)
            warn "Config must yield a hash"
            exit(1)
          end

          @opts.update(cfg)

        rescue Errno::ENOENT
          warn "Config file '#{@opts[:config]}' does not exist"
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

        server = @opts[:server]
        channels = @opts[:channels]

      else
        server = ARGV[0]
        channels = ARGV[1..-1]
      end

      VpsFree::Irc::Bot.start(server, channels, @opts)
    end
  end
end
