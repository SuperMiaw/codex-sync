#!/usr/bin/env bash
set -euo pipefail
[[ $# == 0 ]] || {
	printf 'Usage: uninstall.sh\n' >&2
	exit 2
}
base=$(cd -- "$(dirname -- "$0")" && pwd -P)
status=0
for name in codex-sync cpush cpull; do
	path=$HOME/.local/bin/$name
	[[ -e $path || -L $path ]] || continue
	if [[ -f $path && ! -L $path ]] && cmp -s -- "$base/bin/$name" "$path"; then
		rm -- "$path"
		printf '✅ Removed %s\n' "$path"
	else
		printf '⚠️ Preserved modified or unrelated command: %s\n' "$path" >&2
		status=1
	fi
done
exit "$status"
