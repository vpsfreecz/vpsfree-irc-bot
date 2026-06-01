# frozen_string_literal: true

require 'json'
require 'io/wait'
require 'osvm'
require 'shellwords'
require 'socket'
require 'test-runner/hook'

module IrcBotHostfwdPorts
  PLACEHOLDER = /\birc-[a-z0-9-]+\b/
  @ports = {}

  class << self
    def reserve(name)
      key = name.to_s
      @ports[key] ||= OsVm::PortReservation.get_port(key: "hostfwd:#{key}")
    end

    def port(name)
      @ports[name.to_s]
    end

    def replace_placeholders(str)
      str.gsub(PLACEHOLDER) { |token| reserve(token).to_s }
    end
  end
end

module IrcBotHostfwdUserNetworkPatch
  def qemu_options
    host_forward = @opts['hostForward']
    return super unless host_forward.is_a?(String)

    @opts['hostForward'] = IrcBotHostfwdPorts.replace_placeholders(host_forward)
    super
  ensure
    @opts['hostForward'] = host_forward
  end
end

OsVm::MachineConfig::UserNetwork.prepend(IrcBotHostfwdUserNetworkPatch)

class IrcBotClient
  DEFAULT_TIMEOUT = 30

  attr_reader :channel, :lines, :nick

  def self.connect(port:, nick:, channel:, timeout: DEFAULT_TIMEOUT)
    deadline = Time.now + timeout
    last_error = nil

    loop do
      remaining = deadline - Time.now
      if remaining <= 0
        detail = last_error ? ": #{last_error.class}: #{last_error.message}" : ''
        raise OsVm::TimeoutError,
              "Timed out connecting IRC client #{nick} to 127.0.0.1:#{port}#{detail}"
      end

      begin
        return new(
          port: port,
          nick: nick,
          channel: channel,
          timeout: [remaining, 5].min
        )
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET, OsVm::TimeoutError => e
        last_error = e
        sleep 1
      end
    end
  end

  def initialize(port:, nick:, channel:, timeout: DEFAULT_TIMEOUT)
    @nick = nick
    @channel = channel
    @lines = []
    @socket = TCPSocket.new('127.0.0.1', port)
    @socket.sync = true

    begin
      send_line("NICK #{nick}")
      send_line("USER #{nick} 0 * :#{nick}")
      wait_for(/ 001 #{Regexp.escape(nick)} /, timeout: timeout)
      join(channel)
    rescue StandardError
      close
      raise
    end
  end

  def close
    send_line('QUIT :bye')
  rescue StandardError
    nil
  ensure
    @socket&.close
  end

  def join(channel)
    send_line("JOIN #{channel}")
    wait_for { |line| line.include?(' JOIN ') && line.include?(channel) }
  end

  def privmsg(target, message)
    send_line("PRIVMSG #{target} :#{message}")
  end

  def command(message, target: channel)
    privmsg(target, message)
  end

  def wait_for_names_include(nick, timeout: DEFAULT_TIMEOUT)
    send_line("NAMES #{channel}")

    wait_for(timeout: timeout) do |line|
      next true if line.match?(/\A:#{Regexp.escape(nick)}![^ ]+ JOIN :?#{Regexp.escape(channel)}\z/)

      next false unless line.include?(" 353 #{self.nick} ") && line.include?(channel)

      names = line.split(' :', 2).fetch(1, '').split
      names.map { |name| name.delete_prefix('@').delete_prefix('+') }.include?(nick)
    end
  end

  def wait_for(pattern = nil, timeout: DEFAULT_TIMEOUT)
    deadline = Time.now + timeout

    loop do
      remaining = deadline - Time.now
      if remaining <= 0
        raise OsVm::TimeoutError,
              "Timed out waiting for IRC line #{pattern.inspect}; last lines: #{lines.last(10).inspect}"
      end

      readable = @socket.wait_readable(remaining)
      next unless readable

      line = @socket.gets("\r\n")
      raise 'IRC connection closed' if line.nil?

      line = line.delete_suffix("\r\n")
      @lines << line
      handle_ping(line)

      matched = block_given? ? yield(line) : pattern && line.match?(pattern)
      return line if matched
    end
  end

  def drain(timeout: DEFAULT_TIMEOUT, quiet: 1)
    deadline = Time.now + timeout

    loop do
      remaining = deadline - Time.now
      return if remaining <= 0

      readable = @socket.wait_readable([quiet, remaining].min)
      return unless readable

      line = @socket.gets("\r\n")
      raise 'IRC connection closed' if line.nil?

      line = line.delete_suffix("\r\n")
      @lines << line
      handle_ping(line)
    end
  end

  def wait_for_privmsg(from: nil, target: nil, text: nil, pattern: nil, timeout: DEFAULT_TIMEOUT)
    wait_for(timeout: timeout) do |line|
      msg = parse_privmsg(line)
      next false unless msg

      next false if from && msg[:from] != from
      next false if target && msg[:target] != target
      next false if text && !msg[:text].include?(text)
      next false if pattern && !msg[:text].match?(pattern)

      true
    end
  end

  def wait_for_action(from: nil, target: nil, text: nil, timeout: DEFAULT_TIMEOUT)
    wait_for_privmsg(
      from: from,
      target: target,
      pattern: /\A\u0001ACTION .*#{Regexp.escape(text)}.*\u0001\z/,
      timeout: timeout
    )
  end

  private

  def send_line(line)
    @socket.write("#{line}\r\n")
  end

  def handle_ping(line)
    return unless line.start_with?('PING ')

    send_line("PONG #{line.split(' ', 2).fetch(1)}")
  end

  def parse_privmsg(line)
    match = line.match(/\A:([^!]+)![^ ]+ PRIVMSG ([^ ]+) :(.+)\z/)
    return unless match

    {
      from: match[1],
      target: match[2],
      text: match[3]
    }
  end
end

class VpsadminServicesMachine < OsVm::NixosMachine
  def wait_for_vpsadmin_api(timeout: @default_timeout || 300)
    deadline = Time.now + timeout

    loop do
      raise OsVm::TimeoutError, 'Timed out waiting for vpsAdmin API' if Time.now >= deadline

      _, output = wait_until_succeeds(
        'curl --silent --fail-with-body http://api.vpsadmin.test/',
        timeout: [1, (deadline - Time.now).ceil].max
      )

      return true if output.include?('API description')

      sleep 1
    end
  end

  def api_ruby(code:, timeout: nil)
    script = <<~CMD
      set -euo pipefail
      api_dir="$(systemctl show -p WorkingDirectory --value vpsadmin-api)"
      api_root="$(dirname "$api_dir")"
      tmp_rb="$(mktemp /tmp/vpsfree-irc-bot-it-XXXX.rb)"
      trap 'rm -f "$tmp_rb"' EXIT

      cat > "$tmp_rb" <<'RUBY'
      ENV['RACK_ENV'] ||= 'production'
      require 'json'
      Dir.chdir(ENV.fetch('API_DIR'))
      $LOAD_PATH.unshift(File.join(ENV.fetch('API_DIR'), 'lib'))
      require 'vpsadmin'
      plugin_root = File.expand_path('../plugins', ENV.fetch('API_DIR'))
      %w[newslog outage_reports].each do |plugin|
        Dir[File.join(plugin_root, plugin, 'api', 'models', '*.rb')]
          .sort
          .each { |path| require path }
      end
      #{code}
      RUBY

      API_DIR="$api_dir" "$api_root/ruby-env-wrapped/bin/ruby" "$tmp_rb"
    CMD

    timeout ? succeeds(script, timeout: timeout) : succeeds(script)
  end

  def api_ruby_json(code:, timeout: nil)
    _, output = api_ruby(code: code, timeout: timeout)
    JSON.parse(output.to_s.lines.last)
  end
end

TestRunner::Hook.subscribe(:machine_class_for) do |machine_config|
  next unless machine_config.tags.include?('vpsadmin-services')

  VpsadminServicesMachine
end
