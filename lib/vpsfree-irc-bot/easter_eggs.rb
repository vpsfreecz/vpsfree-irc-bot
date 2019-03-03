module VpsFree::Irc::Bot
  class EasterEggs
    include Cinch::Plugin
    include Api

    class << self
      attr_accessor :instance
    end

    def self.is_time?(probability = 0.1)
      !State.get.muted? && Random.rand(0..1000) <= (probability * 1000)
    end

    def self.cmd_exec(cmd, m, channel, *args)
      case cmd
      when :help
        m.reply([
          "OK, just stay there, I'm coming!",
          "Just keep swimming",
        ].sample)
      
      when :muted?
        m.reply([
          "I dunno, are you?",
        ].sample)
      
      when :ping
        m.reply([
          "I don't feel like playing today",
          "Did you say something?",
          "Hm?",
        ].sample)

      when :status
        down = 0

        instance.client do |api|
          nodes = api.node.public_status
          
          down = nodes.select { |n| !n.attributes[:status] && n.maintenance_lock == 'no' }
        end

        if down.count > 0
          if is_time?(0.2)
            m.reply([
              "Houston, we have a problem",
            ].sample)

          else
            if down.count == 1
              s = down.name
              
              m.reply([
                "#{s} went afk",
                "#{s} went away",
                "#{s} is taking a break",
                "#{s} is taking five",
                "#{s} went to the happy hunting ground",
              ].sample)

            else
              s = "#{down[0..-2].map { |v| v.name }.join(', ')} and #{down.last.name}"
              
              m.reply([
                "#{s} went afk",
                "#{s} went away",
                "#{s} are taking a break",
                "#{s} went to the happy hunting ground",
              ].sample)
            end
          end

        else
          if is_time?(0.3)
            forecast = Forecast.as_text([
              'Prague',
              'Brno',
              'Ostrava',
              'Bratislava',
            ].sample)

            m.reply("Weather in #{forecast}")

          else
            m.reply([
              "No, not today. Please, not today!",
              "I'm almost afraid to look. Are you sure?",
              "Why, I'm fine, thanks for asking",
              "It's.. ummmm.. fine, everything is just fine",
            ].sample)
          end
        end
     
      when :uptime
        m.reply([
          "Sorry, I've lost count",
          "Sorry, I've lost track of time",
        ].sample)

      else
        return false
      end

      true
    end

    def post_api_setup
      self.class.instance = self
    end
  end
end
