require 'htmlentities'
require 'rinku'
require 'vpsfree-irc-bot/template_logger'

module VpsFree::Irc::Bot
  class TemplateLogger
    class Renderer
      def encode(v, hashtag = false)
        ret = @coder.encode(v, :basic)
        ret.gsub!(/#/, '%23') if hashtag
        ret
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

      # On NixOS, the copied files are not user-writable, which prevents us
      # from overwriting the assets in case they're updated.
      Dir.glob(File.join(@dst, 'assets', '*')).each do |f|
        File.chmod(0644, f)
      end
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
