#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
mkdir -p "$tmp/work/demo/sub/bad name/deep" "$tmp/launch"
ln -s "$tmp/work/demo/sub/bad name/deep" "$tmp/launch/alias"
for invocation in "$tmp/work/demo/sub/bad name/deep" "$tmp/launch/alias"; do
	cd "$invocation"
	for direction in push pull; do
		run "$direction" --dry-run
		mapfile -t args <"$LOG.rsync"
		if [[ $direction == push ]]; then
			[[ ${args[-2]} == "$tmp/work/demo/" && ${args[-1]} == 'codex:~/demo/' ]]
		else
			[[ ${args[-2]} == 'codex:~/demo/' && ${args[-1]} == "$tmp/work/demo/" ]]
		fi
		has "--exclude-from=$tmp/work/demo/.codexignore"
		grep -Fq "p=\"\$HOME/demo\"" "$LOG.ssh"
	done
done
ok 'deep and symlinked invocations transfer the physical marker root with flat remote naming'
touch "$tmp/work/demo/sub/.codexignore"
for direction in push pull; do
	run "$direction"
	has "$tmp/work/demo/sub/"
	has 'codex:~/sub/'
	has "--exclude-from=$tmp/work/demo/sub/.codexignore"
	if has "--exclude-from=$tmp/work/demo/.codexignore"; then exit 1; fi
done
ok 'nested marker selects a new root and ignores ancestor patterns'
mkdir -p "$HOME/project/nested"
touch "$HOME/.codexignore"
cd "$HOME/project/nested"
for direction in push pull; do
	reject "$direction"
	[[ ! -e $LOG.ssh ]]
	grep -Fq 'Refusing to synchronize filesystem root or home directory' "$tmp/err"
done
ok 'home marker is rejected even when invoked from a safe nested directory'
