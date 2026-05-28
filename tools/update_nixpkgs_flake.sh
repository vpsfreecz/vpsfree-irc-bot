#!/usr/bin/env bash

set -euo pipefail

usage() {
	cat <<'EOF'
Usage: tools/update_nixpkgs_flake.sh

Update the nixpkgs flake input and commit the isolated flake.lock change as:

  flake: nixpkgs <old9> -> <new9>

The script refuses to start with tracked changes present and refuses to commit
if the update modifies anything other than flake.lock.
EOF
}

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

nixpkgs_rev() {
	nix flake metadata --json . | jq -er '.locks.nodes.nixpkgs.locked.rev'
}

short_rev() {
	printf '%s' "$1" | cut -c1-9
}

changed_files() {
	git diff --name-only
}

staged_files() {
	git diff --cached --name-only
}

case "${1:-}" in
	-h | --help)
		usage
		exit 0
		;;
	'')
		;;
	*)
		usage >&2
		exit 1
		;;
esac

require_cmd git
require_cmd jq
require_cmd nix

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

[ -f flake.lock ] || die "flake.lock not found in $repo_root"

if ! git diff --quiet || ! git diff --cached --quiet; then
	die "tracked worktree changes are present; commit or stash them first"
fi

old_rev="$(nixpkgs_rev)"
old_short="$(short_rev "$old_rev")"

printf 'Current nixpkgs revision: %s\n' "$old_rev"
nix flake update nixpkgs

mapfile -t changed < <(changed_files)

case "${#changed[@]}" in
	0)
		printf 'nixpkgs is already up to date at %s\n' "$old_rev"
		exit 0
		;;
	1)
		[ "${changed[0]}" = "flake.lock" ] || {
			printf 'Unexpected changed file:\n' >&2
			printf '  %s\n' "${changed[@]}" >&2
			exit 1
		}
		;;
	*)
		printf 'Unexpected changed files:\n' >&2
		printf '  %s\n' "${changed[@]}" >&2
		exit 1
		;;
esac

new_rev="$(nixpkgs_rev)"
new_short="$(short_rev "$new_rev")"

if [ "$old_rev" = "$new_rev" ]; then
	die "flake.lock changed, but nixpkgs remained at $old_rev"
fi

subject="flake: nixpkgs ${old_short} -> ${new_short}"
message_file="$(mktemp)"
trap 'rm -f "$message_file"' EXIT
printf '%s\n' "$subject" > "$message_file"

git add flake.lock
mapfile -t staged < <(staged_files)

if [ "${#staged[@]}" -ne 1 ] || [ "${staged[0]}" != "flake.lock" ]; then
	printf 'Unexpected staged files:\n' >&2
	printf '  %s\n' "${staged[@]}" >&2
	exit 1
fi

git commit -F "$message_file"
printf 'Committed: %s\n' "$subject"
