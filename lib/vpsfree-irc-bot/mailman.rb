require 'mail'

module VpsFree::Irc::Bot
  module MailMan
    class Watcher
      def initialize
        @lists = []
      end

      # @param opts [Hash]
      # @option opts [String] server
      # @option opts [Integer] port
      # @option opts [String] user_name
      # @option opts [String] password
      # @option opts [Boolean] enable_ssl
      def server=(opts)
        ::Mail.defaults do
          retriever_method(:pop3, opts)
        end
      end

      # @param opts [Hash]
      # @option opts [String] name
      # @option opts [String] id List-Id header
      # @option opts [String] prefix subject prefix
      # @option opts [Symbol] method callback name
      def list(opts)
        @lists << MailingList.new(opts)
      end

      # @param plugin [Cinch::Plugin] plugin instance
      def check(plugin)
        ::Mail.find_and_delete.each do |m|
          list = @lists.detect { |list| list.belongs?(m) }

          unless list
            warn "Stray message '#{m.subject}'" unless list
            next
          end

          list.process(m, plugin)
        end
      end
    end

    class MailingList
      attr_reader :name, :id, :prefix

      def initialize(opts)
        opts.each { |k, v| instance_variable_set("@#{k}", v) }
      end

      def belongs?(m)
        m['List-Id'].to_s.strip == @id.strip
      end

      def process(m, plugin)
        plugin.send(@method, self, m, archive_url(m))
      end

      def archive_url(m)
        m['Archived-At'].to_s[1..-2]
      end
    end

    module ClassMethods
      # @yieldparam [Watcher]
      def mailman(&block)
        watcher = Watcher.new

        define_method(:mailman_setup) { instance_exec(watcher, &block) }
        define_method(:mailman_timer) { watcher.check(self) }

        timer(0, method: :mailman_setup, shots: 1, threaded: false)
        timer(60, method: :mailman_timer, threaded: false)

        watcher
      end
    end

    def self.included(klass)
      klass.send(:extend, ClassMethods)
    end
  end
end
