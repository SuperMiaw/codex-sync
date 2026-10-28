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
run pull --dry-run
has --dry-run
has --delete
[[ ! -s $tmp/err ]]
mapfile -t args <"$LOG.rsync"
[[ ${args[-2]} == 'codex:~/demo/' && ${args[-1]} == "$tmp/work/demo/" ]]
ok 'pull reverses endpoints and dry-run previews deletion'
run push --no-delete
if has --delete; then exit 1; fi
[[ ! -s $tmp/err ]]
ok 'no-delete removes deletion and warning'
for direction in push pull; do
	run "$direction"
	has --delete
	[[ $(cat "$tmp/err") == '⚠️ Sync will delete destination-only files.' ]]
	for mode in '--dry-run' '--no-delete' '--dry-run --no-delete'; do
		read -r -a mode_args <<<"$mode"
		run "$direction" "${mode_args[@]}"
		[[ ! -s $tmp/err ]]
	done
done
ok 'both directions warn only for real deleting syncs'
