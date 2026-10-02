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

## GitHub notifications

Configure GitHub webhook routing under `github_webhook.channels`. Each channel
accepts a list of repository full names or an object with `repositories`,
`event_types`, `default_branch_only`, and `ignored_users`. See the
[sample configuration](dist/config.yml.sample).

`ignored_users` is optional and defaults to an empty list. For pushes with
commits, it filters the original commit author. An author's GitHub username
is used when present; otherwise, a username can be recovered from a GitHub
noreply email. Commits with unknown authors remain visible. Matching uses exact,
case-sensitive usernames and does not use display names or committers.

A push with only ignored authors produces no announcement. Mixed pushes show
only retained commits, in their original order, with at most ten commit lines.
Summaries and overflow counts refer to retained commits, and summaries state
how many commits were ignored. The comparison link still shows the whole push.
Force-push and fast-forward announcements include the retained commit details.
The account pushing the commits does not override their authorship.

For events without commits, including issues, pull requests, and eligible empty
pushes, `ignored_users` filters the event sender. Filtering is independent for
each channel. An absent or empty list preserves the existing announcement
format and routing behavior.

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
