vpsFree.cz IRC Bot
==================

## Deployment with systemd

The systemd service `vpsfree-irc-bot@.service` runs the bot as user `vpsfbot`. The bot's
executable must be in `$PATH`. Bots are configured by config files located at
`/etc/vpsfree-irc-bot/%i.yml`, where `%i` is service instance name.

    # useradd -m -d /home/vpsfbot -s /bin/false vpsfbot
    # mkdir /etc/vpsfree-irc-bot
