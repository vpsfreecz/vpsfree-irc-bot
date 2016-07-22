require 'fileutils'
require 'erb'
require 'date'
require 'thread'

module VpsFree::Irc::Bot
  class TemplateLogger
    class Renderer
      def initialize(tpl)
        @erb = ERB.new(File.new(tpl).read, 0, '-')
        @coder = HTMLEntities.new
      end

      def render(opts)
        opts.each { |k, v| instance_variable_set("@#{k}", v) }
        ret = @erb.result(binding)
        opts.each { |k, v| instance_variable_set("@#{k}", nil) }
        ret
      end
    end

    def initialize(channel, tpl, dir, path)
      @channel = channel
      @tpl = tpl
      @path = path
      @dst = dir
      @mutex = Mutex.new
      @renderers = {}

      open
    end

    def log(type, m, *args)
      tpl = type
      opts = {
          m: m,
          time: m.time,
          counter: @counter,
      }

      case type
      when :me
        opts[:status] = m.message['ACTION'.size + 2..-2]

      when :join
        opts[:event] = 'has joined'

      when :leave
        if m.command == 'KICK'
          type = :kick
          opts[:op] = m.user
          opts[:user] = args.first
          opts[:reason] = m.params[2].empty? ? nil : m.params[2]

        else
          opts[:event] = 'has left'
        end
      end

      opts[:type] = type

      tr = {
          join: :action,
          leave: :action,
      }

      write(tr.has_key?(type) ? tr[type] : type, opts)
    end

    def next_day
      t = Time.now

      @mutex.synchronize do
        if next_day?(t)
          close
          open
        end
      end
    end

    protected
    def open
      @opened_at = Time.now
      @counter = 0
      @file = File.join(@dst, format_path(@opened_at))
      @dir = File.dirname(@file)

      FileUtils.mkpath(@dir)

      if File.exists?(@file) && File.size(@file) > 0
        open_existing

      else
        open_new
      end
    end

    def open_new
      @handle = File.open(@file, 'w')
      @handle.write(header)
      @handle.flush
    end

    def open_existing
      @counter = last_counter
      @handle = File.open(@file, 'a')
    end

    def write(*args)
      t = Time.now

      @mutex.synchronize do
        if next_day?(t)
          close
          open
        end

        tz_changed(t) if t.gmt_offset != @opened_at.gmt_offset

        @handle.write(render(*args))
        @handle.flush
        @counter += 1
      end
    end

    def close
      @handle.write(render(:footer))
      @handle.close
    end

    def header
      to_root = Array.new(@path.count('/'), '..')

      render(
          :header,
          channel: @channel,
          time: @opened_at,
          previous: File.join(
              *to_root,
              format_path(@opened_at.to_date.prev_day),
          ),
          next: File.join(
              *to_root,
              format_path(@opened_at.to_date.next_day),
          ),
          root: File.join(*to_root),
      )
    end

    def tz_changed

    end

    def render(name, opts = {})
      unless @renderers[name]
        @renderers[name] = Renderer.new(template(name))
      end

      @renderers[name].render(opts)
    end

    def last_counter
      0
    end

    def template_dir
      File.join(
          File.dirname(File.realpath(__FILE__)),
          '..', '..',
          'templates',
          @tpl,
      ) 
    end

    def template(name)
      File.join(
          template_dir,
          "#{name}.erb",
      )
    end

    def format_path(t)
      t.strftime(@path) % {
          server: @channel.bot.config.server,
          channel: @channel.to_s,
      }
    end

    def next_day?(t)
      ! (@opened_at.to_date === t.to_date)
    end
  end
end
