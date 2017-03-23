module VpsFree::Irc::Bot
  class FileStorage < Persistence
    # @param server [String]
    # @param name [Symbol]
    # @return [FileStorage]
    def self.get(server, name)
      @instances ||= {}
      @instances[server] ||= {}
      @instances[server][name] ||= new(server, name)
    end

    private
    def initialize(server, name)
      @name = name
      @data = {}
      super(server)
    end

    public
    def [](k)
      do_sync do
        @changed = true
        @data[k]
      end
    end

    def []=(k, v)
      do_sync do
        @changed = true
        @data[k] = v
      end
    end

    def each(&block)
      ret = nil

      do_sync do
        ret = @data.each(&block)
        @changed = true
      end

      ret
    end

    def empty?
      do_sync { @data.empty? }
    end

    def delete(k)
      do_sync do
        @changed = true
        @data.delete(k)
      end
    end

    include Enumerable
    
    protected
    def load
      return unless File.exists?(save_file)
      
      @data = YAML.load(File.read(save_file))
    end

    def save
      FileUtils.mkpath(save_dir)

      File.open("#{save_file}.new", 'w') do |f|
        f.write(YAML.dump(@data))
      end

      FileUtils.mv("#{save_file}.new", save_file)
    end

    def persistence
      Thread.new do
        loop do
          sleep(15)

          do_sync do
            save if @changed
            @changed = false
          end
        end
      end
    end

    def save_file
      File.join(save_dir, "#{@name}.yml")
    end
  end
end
