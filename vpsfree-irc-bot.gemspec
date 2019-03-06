# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vpsfree-irc-bot/version'

Gem::Specification.new do |spec|
  spec.name          = 'vpsfree-irc-bot'
  spec.version       = VpsFree::Irc::Bot::VERSION
  spec.authors       = ['Jakub Skokan']
  spec.email         = ['jakub.skokan@vpsfree.cz']
  spec.summary       =
  spec.description   = 'IRC bot for vpsFree.cz'
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'

  spec.add_runtime_dependency 'cinch', '~> 2.3.2'
  spec.add_runtime_dependency 'htmlentities'
  spec.add_runtime_dependency 'rinku'
  spec.add_runtime_dependency 'nokogiri'
  spec.add_runtime_dependency 'haveapi-client', '~> 0.12.0'
  spec.add_runtime_dependency 'json'
  spec.add_runtime_dependency 'reverse_markdown'
  spec.add_runtime_dependency 'mail'
  spec.add_runtime_dependency 'chronic_duration'
  spec.add_runtime_dependency 'require_all', '~> 2.0.0'
  spec.add_runtime_dependency 'sinatra', '~> 2.0.5'
  spec.add_runtime_dependency 'thin'
  spec.add_runtime_dependency 'xmlrpc' if RUBY_VERSION >= '2.3'
end
