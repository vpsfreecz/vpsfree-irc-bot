require 'htmlentities'
require 'rinku'

module VpsFree::Irc::Bot
  class TemplateLogger
    class Renderer
      def encode(v)
        @coder.encode(v, :basic)
      end

      def auto_link(v)
        Rinku.auto_link(encode(v), :urls, 'target="_blank" rel="nofollow"')
      end
    end
  end

  class HtmlLogger < TemplateLogger
    def initialize(*args)
      super
      copy_assets
    end

    protected
    def copy_assets
      assets = File.join(template_dir, 'assets')
      return unless Dir.exists?(assets)

      FileUtils.mkdir_p(File.join(@dst, 'assets'))
      FileUtils::cp_r(assets, @dst)
    end
  end
end
