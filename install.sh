#!/usr/bin/env bash
set -euo pipefail
base=$(cd -- "$(dirname -- "$0")" && pwd -P)
force=false
case ${1:-} in
--force)
	force=true
	shift
	;;
--help)
	printf 'Usage: install.sh [--force]\n'
	exit 0
	;;
esac
[[ $# == 0 ]] || {
	printf 'Usage: install.sh [--force]\n' >&2
	exit 2
}
target=$HOME/.local/bin
names=(codex-sync cpush cpull)
collisions=()
for name in "${names[@]}"; do
	path=$target/$name
	[[ ! -d $path ]] || {
		printf '❌ Cannot replace directory: %s\n' "$path" >&2
		exit 1
	}
	if [[ -e $path || -L $path ]]; then
		if [[ -L $path ]] || ! cmp -s -- "$base/bin/$name" "$path"; then collisions+=("$path"); fi
	fi
done
if ((${#collisions[@]})); then
	printf '⚠️ Existing command collisions:\n' >&2
	printf '  %s\n' "${collisions[@]}" >&2
	if ! $force; then
		[[ -t 0 ]] || {
			printf '❌ Noninteractive collision: use --force to replace.\n' >&2
			exit 1
		}
		read -r -p '⚠️ Replace these files? [y/N] ' answer || exit 1
		[[ $answer == y || $answer == Y || $answer == yes ]] || exit 1
	fi
fi
mkdir -p -- "$target"
stage=$(mktemp -d "$target/.codex-sync.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
for name in "${names[@]}"; do install -m 755 -- "$base/bin/$name" "$stage/$name"; done
for name in "${names[@]}"; do mv -fT -- "$stage/$name" "$target/$name"; done
printf '✅ Installed commands in %s\n' "$target"
