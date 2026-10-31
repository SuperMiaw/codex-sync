#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
cd "$tmp/work/demo"
run push
[[ $(cat "$tmp/out") == "ℹ️ push: $tmp/work/demo/ -> codex:~/demo/" ]]
has "$tmp/work/demo/"
has 'codex:~/demo/'
has --delete
[[ $(cat "$tmp/err") == '⚠️ Sync will delete destination-only files.' ]]
[[ $(head -n 1 "$LOG.ssh") == codex ]]
ok 'current directory without Git, default host, deletion warning, trailing slashes'
for direction in push pull; do
	run "$direction"
	mapfile -t args <"$LOG.rsync"
	if [[ $direction == push ]]; then
		[[ ${args[-2]} == "$PWD/" && ${args[-1]} == 'codex:~/demo/' ]]
	else
		[[ ${args[-2]} == 'codex:~/demo/' && ${args[-1]} == "$PWD/" ]]
	fi
	has --delete
	[[ $(cat "$tmp/err") == '⚠️ Sync will delete destination-only files.' ]]
	for mode in '--dry-run' '--no-delete' '--dry-run --no-delete'; do
		read -r -a mode_args <<<"$mode"
		run "$direction" "${mode_args[@]}"
		[[ ! -s $tmp/err ]]
		if [[ $mode == *--dry-run* ]]; then has --dry-run; fi
		if [[ $mode == *--no-delete* ]]; then
			if has --delete; then exit 1; fi
		else
			has --delete
		fi
	done
done
ok 'both directions warn only for real deleting syncs'
