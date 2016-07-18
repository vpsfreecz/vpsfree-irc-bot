require 'optparse'

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
Usage: #{$0} [options] <server> <channel...>

Options:
END

      opt_parser = OptionParser.new do |opts|
        opts.banner = usage

        opts.on('-a', '--api URL', 'URL to the vpsAdmin API server') do |u|
          @opts[:api_url] = u
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

      if ARGV.size < 2
        puts opt_parser
        exit(1)
      end

      VpsFree::Irc::Bot.start(ARGV[0], ARGV[1..-1], @opts)
    end
  end
end
