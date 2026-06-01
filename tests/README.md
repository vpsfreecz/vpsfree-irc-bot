# Integration tests

This repository reuses the vpsAdminOS VM test framework through flake outputs.

Run the suite with:

```sh
./test-runner.sh ls
./test-runner.sh test irc-basic
./test-runner.sh test vpsadmin-events
```

`irc-basic` boots only a small NixOS VM with ngIRCd and the bot. It covers IRC
connectivity and commands that do not require vpsAdmin or other external
services.

`vpsadmin-events` additionally boots the vpsAdmin services VM and verifies the
bot can poll vpsAdmin and announce news/outage events on IRC.
