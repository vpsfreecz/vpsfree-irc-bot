# Integration tests

This repository reuses the vpsAdminOS VM test framework through flake outputs.

Run the suite with:

```sh
./test-runner.sh ls
./test-runner.sh test irc-basic
./test-runner.sh test irc-github-webhook
./test-runner.sh test vpsadmin-events
```

`irc-basic` boots only a small NixOS VM with ngIRCd and the bot. It covers IRC
connectivity and commands that do not require vpsAdmin or other external
services.

`vpsadmin-events` additionally boots the vpsAdmin services VM and verifies the
bot can poll vpsAdmin and announce news/outage events on IRC.

`irc-github-webhook` boots the same small IRC environment and posts signed GitHub
webhook fixtures to the bot. It checks per-channel commit filtering, message and
archive contents, force-push details, sender filtering, and invalid signatures.
All webhook requests run inside the test VM; IRC clients connect only to its
forwarded test port.
