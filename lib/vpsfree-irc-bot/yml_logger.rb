module VpsFree::Irc::Bot
  class TemplateLogger
    class Renderer
      def yml_escape(v)
        v.gsub(/'/, "''")
      end
    end
  end
end
