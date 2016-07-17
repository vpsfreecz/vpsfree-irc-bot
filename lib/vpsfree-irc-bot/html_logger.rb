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
    def open_new
      super
      write_tz(@opened_at)
    end

    def copy_assets
      assets = File.join(template_dir, 'assets')
      return unless Dir.exists?(assets)

      FileUtils.mkdir_p(File.join(@dst, 'assets'))
      FileUtils::cp_r(assets, @dst)
    end

    def last_counter
      rx = /<[^>]*id="l(\d+)"/

      File.readlines(@file).reverse_each do |line|
        match = rx.match(line)
        return match[1].to_i + 1 if match
      end

      0
    end

    def write_tz(t)
      @handle.write(render(:tz, counter: @counter, time: t))
      @handle.flush
      @counter += 1
    end

    def tz_changed(t)
      write_tz(t)
    end
  end
end
