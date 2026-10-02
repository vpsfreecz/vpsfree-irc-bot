# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'timeout'

RSpec.describe VpsFree::Irc::Bot::HtmlLogger do
  let(:root) { Dir.mktmpdir('vpsfree-html-logger-', '/tmp') }
  let(:destination) { File.join(root, 'archive') }
  let(:opened_loggers) { Queue.new }
  let(:installer_entries) { Queue.new }
  let(:logger_class) do
    templates = template_directory
    loggers = opened_loggers
    entries = installer_entries

    Class.new(described_class) do
      define_method(:initialize) do |*args|
        loggers << self
        super(*args)
      end

      define_method(:template_dir) { templates }

      define_method(:copy_assets) do
        entries << Thread.current.thread_variable_get(:asset_installer)
        super()
      end
    end
  end

  before do
    FileUtils.cp_r(File.expand_path('../../../../templates/html', __dir__), template_directory)
    asset_names.each { |name| File.chmod(0o444, File.join(source_assets, name)) }
  end

  after do
    opened_loggers.pop.send(:close) until opened_loggers.empty?
    FileUtils.remove_entry(root)
  end

  it 'serializes copying and all permission changes across channel constructors' do
    events = Queue.new
    copied = Queue.new
    release = Queue.new
    workers = []
    names = asset_names

    allow(FileUtils).to receive(:cp_r).and_wrap_original do |original, source, target|
      role = Thread.current.thread_variable_get(:asset_installer)
      events << [role, :copy_started]
      result = original.call(source, target)
      events << [role, :copy_finished]
      if role == :first
        copied << true
        bounded_pop(release)
      end
      result
    end
    allow(File).to receive(:chmod).and_wrap_original do |original, mode, path|
      result = original.call(mode, path)
      events << [Thread.current.thread_variable_get(:asset_installer), :chmod, File.basename(path)]
      result
    end

    begin
      workers << installer(:first, '#vpsfree')
      expect(bounded_pop(installer_entries)).to eq(:first)
      bounded_pop(copied)
      workers << installer(:second, '#vpsadminos')
      expect(bounded_pop(installer_entries)).to eq(:second)

      # Wait until the second installer blocks on synchronization or completes.
      # Completion also catches the broken copy order under privileged users.
      Timeout.timeout(5) do
        Thread.pass until !workers.last.alive? || waiting_for_lock?(workers.last)
      end
      release << true
      workers.each { |worker| expect(worker.join(5)).to equal(worker) }
      loggers = workers.map(&:value)

      expected = %i[first second].flat_map do |role|
        [[role, :copy_started], [role, :copy_finished]] + names.map { |name| [role, :chmod, name] }
      end
      expect(events.size.times.map { events.pop }).to eq(expected)
      loggers.each_with_index { |logger, index| expect_marker(logger, "channel-#{index}") }
      expect_assets
    ensure
      release << true
      workers.each do |worker|
        unless worker.join(5)
          worker.kill
          worker.join(5)
        end
      end
    end
  end

  it 'refreshes existing assets on subsequent construction' do
    new_logger('#vpsfree')
    asset = File.join(source_assets, asset_names.first)
    File.chmod(0o644, asset)
    File.write(asset, 'updated asset contents')
    File.chmod(0o444, asset)

    expect_marker(new_logger('#vpsadminos'), 'refreshed')
    expect_assets
    expect(File.read(File.join(destination, 'assets', File.basename(asset)))).to eq('updated asset contents')
  end

  it 'keeps logging when the template has no assets' do
    FileUtils.remove_entry(source_assets)

    expect_marker(new_logger('#vpsfree'), 'no-assets')
    expect(File.exist?(File.join(destination, 'assets'))).to be(false)
  end

  it 'propagates copy failures and releases the shared lock for another installer' do
    copies = 0
    allow(FileUtils).to receive(:cp_r).and_wrap_original do |original, source, target|
      copies += 1
      raise Errno::EIO, 'injected copy failure' if copies == 1

      original.call(source, target)
    end

    expect { new_logger('#vpsfree') }.to raise_error(Errno::EIO, /injected copy failure/)
    logger = Timeout.timeout(5) { new_logger('#vpsadminos') }
    expect_marker(logger, 'after-copy-failure')
    expect_assets
  end

  def template_directory
    File.join(root, 'templates')
  end

  def source_assets
    File.join(template_directory, 'assets')
  end

  def asset_names
    Dir.children(source_assets).sort
  end

  def new_logger(channel)
    path = VpsFree::Irc::Bot::LogPath.new('html').resolve(server: 'irc.test', channel: channel)
    logger_class.new('irc.test', channel, 'html', destination, path)
  end

  def installer(role, channel)
    Thread.new do
      Thread.current.report_on_exception = false
      Thread.current.thread_variable_set(:asset_installer, role)
      new_logger(channel)
    end
  end

  def bounded_pop(queue)
    Timeout.timeout(5) { queue.pop }
  end

  def waiting_for_lock?(worker)
    worker.status == 'sleep' && worker.backtrace_locations&.any? { |location| location.label == 'synchronize' }
  end

  def expect_marker(logger, marker)
    user = Struct.new(:nick).new('author')
    message = Struct.new(:time, :user, :message).new(Time.now, user, marker)
    logger.log(:notice, message)
    file = logger.instance_variable_get(:@file)
    expect(File.read(file)).to include(marker)
  end

  def expect_assets
    asset_names.each do |name|
      source = File.join(source_assets, name)
      target = File.join(destination, 'assets', name)
      expect(File.binread(target)).to eq(File.binread(source))
      expect(File.stat(target).mode & 0o777).to eq(0o644)
      expect(File.stat(source).mode & 0o777).to eq(0o444)
    end
  end
end
