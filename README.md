vpsFree.cz IRC Bot
==================

An IRC bot which can be found on irc.libera.chat #vpsfree and #vpsadminos.
Provides channel log and integration with vpsFree.cz's infrastructure.

More information can be also found in
[vpsFree.cz's knowledge base](https://kb.vpsfree.org/information/chat#bot).

## Deployment with Nix

NixOS module, package and configuration can be found at
[vpsfree-cz-configuration](https://github.com/vpsfreecz/vpsfree-cz-configuration).

## Development

Enter the development shell with:

     nix develop

It installs bundled gems into `.gems`. Run checks from the shell with:

     bundle exec rspec
     bundle exec rubocop

## Bundix
Until [bundix#68](https://github.com/nix-community/bundix/pull/68) is resolved, use:

     nix develop -c bash -lc '
       bundle config set --local force_ruby_platform true
       rm -f gemset.nix Gemfile.lock
       bundle lock --add-platform ruby
       BUNDLE_FORCE_RUBY_PLATFORM=true bundix -l
     '

Our issue is with nokogiri, which uses platform-specific gems that bundler has
problems with.
