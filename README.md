vpsFree.cz IRC Bot
==================

An IRC bot which can be found on irc.libera.chat #vpsfree and #vpsadminos.
Provides channel log and integration with vpsFree.cz's infrastructure.

More information can be also found in
(https://kb.vpsfree.org/information/chat#bot)[vpsFree.cz's knowledge base].

## Deployment with Nix

NixOS module, package and configuration can be found at
(https://github.com/vpsfreecz/vpsfree-cz-configuration)[vpsfree-cz-configuration].

## Bundix
Until (https://github.com/nix-community/bundix/pull/68)[bundix#68] is resolved, use:

     bundle config set --local force_ruby_platform true

before

     bundix -l

Our issue is with nokogiri, which uses platform-specific gems that bundler has
problems with.
