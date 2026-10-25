#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
mkdir -p "$HOME/projects/demo"
printf '%s\n' "$HOME/projects" >"$XDG_CONFIG_HOME/codex-sync/project-folders"
cd "$tmp"
printf 'sandbox-example\n' >"$XDG_CONFIG_HOME/codex-sync/target-host"
printf 'global-cache/\n' >"$XDG_CONFIG_HOME/codex-sync/ignore"
printf 'local-cache/\n' >"$HOME/projects/demo/.codexignore"
run pull demo
[[ $(head -n 1 "$LOG.ssh") == sandbox-example ]]
has "--exclude-from=$XDG_CONFIG_HOME/codex-sync/ignore"
has "--exclude-from=$HOME/projects/demo/.codexignore"
mapfile -t builtins < <(grep '^--exclude=' "$LOG.rsync")
[[ ${#builtins[@]} == 3 ]]
[[ ${builtins[0]} == '--exclude=.git/' ]]
[[ ${builtins[1]} == '--exclude=.ssh/' ]]
[[ ${builtins[2]} == '--exclude=.codexignore' ]]
if has --delete-excluded; then exit 1; fi
ok 'XDG target, local ignores on pull, cumulative built-in excludes'
printf '!\n' >>"$HOME/projects/demo/.codexignore"
reject pull demo
[[ ! -e $LOG.ssh ]]
printf 'local-cache/\n' >"$HOME/projects/demo/.codexignore"
ok 'list-clearing rules cannot erase mandatory exclusions'

for direction in push pull; do
	rm "$HOME/projects/demo/.codexignore"
	reject "$direction" demo
	[[ ! -e $LOG.ssh ]]
	grep -Fq "$HOME/projects/demo/.codexignore" "$tmp/err"
	grep -Fq 'empty file is valid' "$tmp/err"
	mkdir "$HOME/projects/demo/.codexignore"
	reject "$direction" demo
	[[ ! -e $LOG.ssh ]]
	rmdir "$HOME/projects/demo/.codexignore"
	touch "$HOME/projects/demo/.codexignore"
	chmod 000 "$HOME/projects/demo/.codexignore"
	if [[ ! -r $HOME/projects/demo/.codexignore ]]; then
		reject "$direction" demo
		[[ ! -e $LOG.ssh ]]
		grep -Fq 'not a readable regular file' "$tmp/err"
	else
		printf 'skip - unreadable file check requires a user without read override\n'
	fi
	chmod 600 "$HOME/projects/demo/.codexignore"
	run "$direction" demo
	[[ -e $LOG.ssh ]]
	has "--exclude-from=$HOME/projects/demo/.codexignore"
	has "--exclude-from=$XDG_CONFIG_HOME/codex-sync/ignore"
done
ok 'both directions require a readable regular local ignore even with global ignore; empty is valid'
rm "$XDG_CONFIG_HOME/codex-sync/ignore"
for direction in push pull; do
	run "$direction" demo
	has "--exclude-from=$HOME/projects/demo/.codexignore"
	if has "--exclude-from=$XDG_CONFIG_HOME/codex-sync/ignore"; then exit 1; fi
done
ok 'global ignore remains optional with empty required local ignore'
