module VpsFree::Irc::Bot::DiscourseWebHook
  class Event
    class << self
      # Register class handler for event type
      # @param type [Symbol]
      # @param klass [Class]
      def register(type, klass)
        @events ||= {}
        @events[type.to_s] = klass
      end

      # Parse event type and payload
      # @param instance [String]
      # @param type [String]
      # @param payload [Hash]
      # @return [Event, nil]
      def parse(instance, type, payload)
        klass = Event.for(type)

        if klass.nil?
          puts "event type '#{type}' is not supported"
          return
        end

        klass.new(instance, type, payload)
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
    end

    attr_reader :instance, :type

    # @param instance [String]
    # @param type [String]
    # @param payload [Hash]
    def initialize(instance, type, payload)
      @instance = instance
      @type = type
      parse(payload)
    end

    def parse(payload)
      # reimplement
    end

    def announce?
      true
    end
  end

  class TopicCreated < Event
    event :topic_created

    def parse(payload)
      topic = payload['topic']

      @topic_url = File.join(
        instance,
        't',
        topic['slug'],
        topic['id'].to_s,
      )

      @title = topic['title']
      @username = topic['created_by']['username']
    end

    def to_s
      "[Discourse] #{@username} created topic #{@title}: #{@topic_url}"
    end
  end

  class PostCreated < Event
    event :post_created

    def parse(payload)
      post = payload['post']

      @post_url = File.join(
        instance,
        't',
        post['topic_slug'],
        post['topic_id'].to_s,
        post['post_number'].to_s,
      )

      @topic_title = post['topic_title']
      @username = post['username']
    end

    def to_s
      "[Discourse] #{@username} posted to #{@topic_title}: #{@post_url}"
    end
  end
end
