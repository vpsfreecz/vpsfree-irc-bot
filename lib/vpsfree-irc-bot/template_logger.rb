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

    def initialize(tpl, dir, path)
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
        opts[:status] = m.message['ACTION'.size + 2..-1]

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

      write(render(tr.has_key?(type) ? tr[type] : type, opts))
      @counter += 1
    end

    protected
    def open
      @opened_at = Time.now
      @counter = 0
      @file = File.join(@dst, @opened_at.strftime(@path))
      @dir = File.dirname(@file)

      FileUtils.mkpath(@dir)

      if File.exists?(@file) && File.size(@file) > 0
        @counter = last_counter
        @handle = File.open(@file, 'a')

      else
        @handle = File.open(@file, 'w')
        @handle.write(header)
        @handle.flush
      end
    end

    def write(str)
      @mutex.synchronize do
        if ! (@opened_at.to_date === Time.now.to_date)
          close
          open
        end

        @handle.write(str)
        @handle.flush
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
          time: @opened_at,
          previous: File.join(
              *to_root,
              @opened_at.to_date.prev_day.strftime(@path),
          ),
          next: File.join(
              *to_root,
              @opened_at.to_date.next_day.strftime(@path),
          ),
          root: File.join(*to_root),
      )
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
  end
end
