module VpsFree::Irc::Bot::GitHubWebHook
  module Helpers
    def extract(payload, *attrs)
      attrs.each do |attr|
        instance_variable_set("@#{attr}", payload[attr.to_s])
      end
    end
  end

  class Event
    include Helpers

    class << self
      # Register class handler for event type
      # @param type [Symbol]
      # @param klass [Class]
      def register(type, klass)
        @events ||= {}
        @events[type.to_s] = klass
      end

      # Parse event type and payload
      # @param type [String]
      # @param payload [Hash]
      # @return [Event, nil]
      def parse(type, payload)
        klass = Event.for(type)

        if klass.nil?
          puts "event type '#{type}' is not supported"
          return
        end

        klass.new(type, payload)
      end

      # Return class for event type
      # @param type [String]
      # @return [Class, nil]
      def for(type)
        @events[type]
      end

      # Use in subclass to register event type
      # @param type [Symbol]
      def event(type)
        Event.register(type, self)
      end

      # Attributes to automatically extract from payload
      attr_reader :to_extract

      # Select attributes for auto-extraction from payload
      def extract(*attrs)
        @to_extract = attrs
        attr_reader *attrs
      end
    end

    attr_reader :type, :sender, :repository

    # @param type [String]
    # @param payload [Hash]
    def initialize(type, payload)
      @type = type
      @sender = User.new(payload['sender'])
      @repository = Repository.new(payload['repository']) if payload['repository']
      extract(payload, *self.class.to_extract) if self.class.to_extract
      parse(payload)
    end
    
    def parse(payload)
      # reimplement
    end

    def announce?
      true
    end
  end
  
  class User
    include Helpers
    attr_reader :id, :login, :html_url

    def initialize(data)
      extract(data, *%i(id login html_url))
    end
  end

  class Repository
    include Helpers
    attr_reader :id, :name, :full_name, :owner, :html_url, :description

    def initialize(data)
      extract(data, *%i(id name full_name html_url description))
      @owner = User.new(data['owner'])
    end
  end

  class Commit
    Author = Struct.new(:name, :email)

    include Helpers
    attr_reader :id, :message, :author, :distinct
    
    def initialize(data)
      extract(data, *%i(id message distinct))
      @author = Author.new(data['author']['name'], data['author']['email'])
    end
  end

  class Issue
    include Helpers
    attr_reader :id, :title, :state, :html_url
    
    def initialize(data)
      extract(data, *%i(id title state html_url))
      @user = User.new(data['user'])
    end
  end

  class PullRequest
    include Helpers
    attr_reader :id, :title, :state, :html_url
    
    def initialize(data)
      extract(data, *%i(id title state html_url))
      @user = User.new(data['user'])
    end
  end

  class CreateEvent < Event
    event :create
    extract *%i(ref_type ref master_branch description)

    def to_s
      <<END
[#{repository.name}] #{sender.login} created #{ref_type} #{ref}
[#{repository.name}] #{repository.html_url}
END
    end
  end

  class DeleteEvent < Event
    event :delete
    extract *%i(ref_type ref)

    def to_s
      <<END
[#{repository.name}] #{sender.login} deleted #{ref_type} #{ref}
[#{repository.name}] #{repository.html_url}
END
    end
  end

  class PushEvent < Event
    event :push
    extract *%i(ref before after created deleted forced compare)
    attr_reader :branch, :commits

    COUNT = 10

    def parse(data)
      @commits = data['commits'].map { |v| Commit.new(v) }
      @branch = ref.split('/').last
    end

    def to_s
      ret = ''
      ret << "[#{repository.name}] #{sender.login} "

      if fast_forward?
        ret << "fast-forwarded #{branch} to #{after[0..8]}"
        return ret
      end

      if forced
        ret << 'force-pushed '
      else
        ret << 'pushed '
      end
      
      ret << "#{commits.count} #{noun(commits.count, 'commit', 'commits')} "
      ret << "to #{branch}\n"
      
      commits[0..COUNT].each do |c|
        ret << "#{repository.name}/#{branch} "
        ret << "#{c.id[0..8]} #{c.author.name}: #{c.message.split("\n").first}"
        ret << "\n"
      end

      if commits.count > COUNT
        ret << "#{repository.name}/#{branch} "
        ret << "...and #{commits.count - COUNT} more "
        ret << "#{noun(commits.count - COUNT, 'commit', 'commits')}\n"
      end

      ret << compare
      ret
    end

    def fast_forward?
      commits.all? { |c| !c.distinct }
    end

    def announce?
      return false if commits.empty? && created
      return false if deleted
      true
    end

    def noun(n, singular, plural)
      n > 1 ? plural : singular
    end
  end

  class ForkEvent < Event
    event :fork
    attr_reader :forkee

    def parse(data)
      @forkee = Repository.new(data['forkee'])
    end

    def to_s
      "#{repository.name} was forked by #{forkee.owner.login}"
    end
  end

  class IssuesEvent < Event
    event :issues
    extract *%i(action)
    attr_reader :issue

    def parse(data)
      @issue = Issue.new(data['issue'])
    end

    def to_s
      <<END
[#{repository.name}] #{sender.login} #{action} issue ##{issue.id}
#{issue.html_url}
END
    end

    def announce?
      %w(opened deleted closed reopened).include?(action)
    end
  end

  class PullRequestEvent < Event
    event :pull_request
    extract *%i(action number)
    attr_reader :pull_request

    def parse(data)
      @pull_request = PullRequest.new(data['pull_request'])
    end

    def to_s
      <<END
[#{repository.name}] #{sender.login} #{action} pull request ##{pull_request.id}
#{pull_request.html_url}
END
    end

    def announce?
      %w(opened deleted closed reopened).include?(action)
    end
  end
end
