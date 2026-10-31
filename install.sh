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
updates=()
collisions=()
changes=()
permissions=()
managed_script() {
	local header marker
	{
		IFS= read -r header && IFS= read -r marker
	} <"$1" || return 1
	[[ $header == '#!/usr/bin/env bash' && $marker == '# codex-sync' ]]
}
for name in "${names[@]}"; do
	path=$target/$name
	if [[ ! -L $path && -e $path && ! -f $path ]]; then
		printf '❌ Cannot replace non-regular file or directory: %s\n' "$path" >&2
		exit 1
	fi
	if [[ -f $path && ! -L $path ]] && cmp -s -- "$base/bin/$name" "$path"; then
		# Restore executable permissions if necessary without rewriting the file.
		if [[ ! -x $path ]]; then permissions+=("$path"); fi
		continue
	fi
	changes+=("$name")
	if [[ -e $path || -L $path ]]; then
		if [[ -f $path && ! -L $path ]] && managed_script "$path"; then
			updates+=("$path")
		else
			collisions+=("$path")
		fi
	fi
done
confirm() {
	local prompt=$1 answer=''
	$force && return 0
	[[ -t 0 && -t 2 ]] || {
		printf '❌ Noninteractive collision: updates/replacements require --force.\n' >&2
		return 1
	}
	printf '⚠️ %s [y/N] ' "$prompt" >&2
	IFS= read -r answer || return 1
	case $answer in
	y | Y | yes | YES | Yes) return 0 ;;
	*) return 1 ;;
	esac
}
# Report and approve the entire set before creating or replacing any target.
if ((${#updates[@]})); then
	printf '⚠️ Existing codex-sync updates:\n' >&2
	printf '  %s\n' "${updates[@]}" >&2
fi
if ((${#collisions[@]})); then
	printf '⚠️ Existing command collisions (unrelated files or symlinks):\n' >&2
	printf '  %s\n' "${collisions[@]}" >&2
fi
if ((${#updates[@]})); then confirm 'Update these codex-sync scripts?' || exit 1; fi
if ((${#collisions[@]})); then confirm 'Replace these unrelated files or symlinks?' || exit 1; fi
mkdir -p -- "$target"
stage=$(mktemp -d "$target/.codex-sync.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
for name in "${changes[@]}"; do install -m 755 -- "$base/bin/$name" "$stage/$name"; done
for path in "${permissions[@]}"; do chmod 755 -- "$path"; done
for name in "${changes[@]}"; do mv -fT -- "$stage/$name" "$target/$name"; done
printf '✅ Installed commands in %s\n' "$target"
