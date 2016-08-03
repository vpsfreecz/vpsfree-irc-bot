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
