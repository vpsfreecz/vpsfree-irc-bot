source 'https://rubygems.org'

begin
  $: << File.realpath(File.join(File.dirname(__FILE__), 'lib'))
rescue Errno::ENOENT
end

group :development do
  gem 'bundler'
  gem 'rake'
end

gem 'grinch', '~> 1.1.0'
gem 'htmlentities'
gem 'rinku'
gem 'nokogiri'
gem 'haveapi-client', '~> 0.26.0'
gem 'json'
gem 'reverse_markdown'
gem 'mail'
gem 'chronic_duration'
gem 'require_all', '~> 2.0.0'
gem 'sinatra', '~> 3.0.5'
gem 'thin'
gem 'xmlrpc'
gem 'rexml' # needed by xmlrpc, a bundled gem since Ruby 3.0
