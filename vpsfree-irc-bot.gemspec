# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vpsfree-irc-bot/version'

Gem::Specification.new do |spec|
  spec.name          = 'vpsfree-irc-bot'
  spec.version       = HaveAPI::Client::VERSION
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

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake'

  spec.add_runtime_dependency 'cinch', '~> 2.3.2'
end
