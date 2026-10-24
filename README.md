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

## Security advisory notifications

Configure `security_advisories.channels` to enable advisory polling from vpsAdmin.
The optional `mode` setting accepts:

- `individual` (default): announce each new published advisory and each update
  with its details and advisory link.
- `summary`: collect distinct new and updated advisory IDs across polls and send
  one line per configured channel, linking to the WebUI advisory list. For example:
  `12 new security advisories, 3 updated in vpsAdmin: <list URL>`.
- `off`: keep polling and updating the advisory store without announcements or
  pending summaries.

In YAML, quote the off value as `mode: 'off'`; an unquoted `off` is parsed as a boolean.

The bot polls every minute. In summary mode, `summary_interval` sets the minimum
time between summaries in seconds. It must be a positive integer and defaults to
`3600` (one hour). Arrivals do not move the deadline or trigger early output.
Empty intervals produce no message. An advisory newly published within a summary
window counts only as new, even if it receives updates in later polls; repeated
updates to an older advisory count once.

Startup silently loads the preceding 30 days of advisories, then waits a full
summary interval before the first possible summary. Pending counts are held only
in memory: a restart discards them and starts a fresh interval. Configure modes
through a normal restart; enabling notifications does not replay events consumed
while off. Muted or failed output is discarded under the bot's existing best-effort
delivery policy.

See the [sample configuration](dist/config.yml.sample). The advisory store format
is unchanged. Older bot versions can read it, but ignore these settings and send
individual notices, so select a compatible bot package when enabling summary or
off mode. Rolling back the bot can restore individual notification volume.

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

## Automated flake updates

The `nixpkgs-update.yml` workflow uses a separately pinned confctl CI package to
require commit ancestry preservation across the full changed lock graph.
Rejected candidates and unavailable evidence stop publication. The workflow
checks the final lock against its saved baseline after hooks and checks, then
uses an ordinary non-force push. If the target branch advances, rerun from its
new baseline instead of rebasing the old lock update.

For a local update, set `CONFCTL_FLAKE` to the immutable package reference in
`.github/workflows/nixpkgs-update.yml`, then run
`tools/update_nixpkgs_flake.sh` and review its generated commit.

The workflow saves confctl's Git mirrors in `~/.cache/confctl` even when an
update is rejected. Every update checks ancestry, whether the cache was
restored or freshly cloned.

See the [shared guard contract](https://github.com/vpsfreecz/confctl/blob/822c0e35dbe2549111912f539116b4225dfd3035/docs/flake-inputs.md#guarded-automated-updates) for supported sources and failure behavior.
