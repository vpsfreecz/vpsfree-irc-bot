vpsFree.cz IRC Bot
==================

## Deployment with systemd

The systemd service `vpsfree-irc-bot@.service` runs the bot as user `vpsfbot`. The bot
should be installed in `/opt/vpsfree-irc-bot` and its executable at
`/opt/vpsfree-irc-bot/bin/vpsfree-irc-bot`.
Bots are configured by config files located at
`/etc/vpsfree-irc-bot/%i.yml`, where `%i` is service instance name.

    # useradd -m -d /home/vpsfbot -s /bin/false vpsfbot
    # mkdir /etc/vpsfree-irc-bot

## Bundix
Until (https://github.com/nix-community/bundix/pull/68)[bundix#68] is resolved, use:

     bundle config set --local force_ruby_platform true

before

     bundix -l

Our issue is with nokogiri, which uses platform-specific gems that bundler has
problems with.
