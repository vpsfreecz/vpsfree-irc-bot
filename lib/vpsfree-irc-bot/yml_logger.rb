module VpsFree::Irc::Bot
  class TemplateLogger
    class Renderer
      def yml_escape(v)
        v ? v.gsub(/'/, "''") : v
      end
    end
  end
end
