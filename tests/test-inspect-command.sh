#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
cd "$tmp/work/demo"
marker=$PWD/.codexignore
global=$XDG_CONFIG_HOME/codex-sync/ignore
# Host configuration is irrelevant to a local diagnostic.
mkdir "$XDG_CONFIG_HOME/codex-sync/target-host"
printf '# comment\n; comment\n\nglobal-cache/\n' >"$global"
printf 'local-cache/\n*.log' >"$marker"
mkdir nested
cd nested
local_report() {
	rm -f "$LOG.ssh" "$LOG.rsync"
	run inspect
	[[ ! -e $LOG.ssh && ! -e $LOG.rsync && ! -s $tmp/err ]]
}
local_report
expected=$(printf 'Sync root: %s\nBuilt-in:\n  .codexignore\n  .git/\n  .ssh/\nGlobal: %s\n  global-cache/\nLocal: %s\n  *.log\n  local-cache/' "$tmp/work/demo" "$global" "$marker")
[[ $(cat "$tmp/out") == "$expected" ]]
ok 'local diagnostic groups rules and paths, using inherited root and XDG configuration'
rm "$global"
local_report
grep -Fx "Global: $global" "$tmp/out"
for directive in '# codex-sync: no-global-ignore' $' \t# codex-sync: no-global-ignore\t\r'; do
	mkdir "$global"
	printf '%s\nlocal-cache/\n%s' "$directive" "$directive" >"$marker"
	local_report
	grep -Fx "Global: $global [disabled]" "$tmp/out"
	grep -Fx '  local-cache/' "$tmp/out"
	[[ $(grep -c 'no-global-ignore' "$tmp/out") == 0 ]]
	rmdir "$global"
done
ok 'absent and directive-disabled global sources are explicit; metadata is omitted'
printf '!\n' >"$global"
printf '# codex-sync: no-global-ignore' >"$marker"
local_report
printf '\n!\n' >>"$marker"
reject inspect
[[ ! -e $LOG.ssh ]]
printf '# codex-sync: NO-GLOBAL-IGNORE\n' >"$marker"
reject inspect
[[ ! -e $LOG.ssh ]]
rm "$global" "$marker"
mkdir "$marker"
reject inspect
[[ ! -e $LOG.ssh ]]
rmdir "$marker"
ln -s "$tmp/missing" "$marker"
reject inspect
[[ ! -e $LOG.ssh ]]
rm "$marker"
touch "$marker"
for arg in --dry-run --no-delete --unknown demo; do
	reject inspect "$arg"
	[[ ! -e $LOG.ssh ]]
done
ok 'shared validation rejects invalid markers and clearing rules; sync options and positional arguments fail locally'
# The removed command is not an alias; informational options remain local.
reject ignore
[[ ! -e $LOG.ssh ]]
run inspect --help
grep -Fq 'codex-sync inspect' "$tmp/out"
run inspect --version
[[ $(cat "$tmp/out") == 'codex-sync 0.1.0' ]]
# Empty sources still have headers; comments are not effective rules.
printf '# comment\n; comment\n\r\n' >"$marker"
local_report
expected=$(printf 'Sync root: %s\nBuilt-in:\n  .codexignore\n  .git/\n  .ssh/\nGlobal: %s\nLocal: %s' "$tmp/work/demo" "$global" "$marker")
[[ $(cat "$tmp/out") == "$expected" ]]
# Preserve origin grouping, duplicate rules, literal whitespace and final lines.
printf 'shared/\nshared/' >"$global"
printf 'shared/\n padded/\n' >"$marker"
local_report
expected=$(printf 'Sync root: %s\nBuilt-in:\n  .codexignore\n  .git/\n  .ssh/\nGlobal: %s\n  shared/\n  shared/\nLocal: %s\n   padded/\n  shared/' "$tmp/work/demo" "$global" "$marker")
[[ $(cat "$tmp/out") == "$expected" ]]
ok 'inspect rejects the old command and sorts displayed rules within each origin and preserves duplicates and empty active sources'
# A directive-like global line with leading spaces is an ordinary rsync rule.
printf '  # codex-sync: no-global-ignore\n' >"$global"
local_report
grep -Fx "Global: $global" "$tmp/out"
[[ $(grep -Fxc '    # codex-sync: no-global-ignore' "$tmp/out") == 1 ]]
ok 'global directive-like rules retain ordinary rsync semantics'
# HOME shortening is display-only and respects directory boundaries.
mkdir -p "$HOME/my-app" "$HOME-sibling/my-app" "$HOME/.config/codex-sync"
printf 'zebra/\nAlpha/\n.env\n' >"$HOME/my-app/.codexignore"
: >"$HOME/.config/codex-sync/ignore"
cd "$HOME/my-app"
XDG_CONFIG_HOME="$HOME/.config" local_report
expected=$'Sync root: ~/my-app\nBuilt-in:\n  .codexignore\n  .git/\n  .ssh/\nGlobal: ~/.config/codex-sync/ignore\nLocal: ~/my-app/.codexignore\n  .env\n  Alpha/\n  zebra/'
[[ $(cat "$tmp/out") == "$expected" ]]
printf '# codex-sync: no-global-ignore\n.env\n' >.codexignore
printf 'hidden-global/\n' >"$HOME/.config/codex-sync/ignore"
XDG_CONFIG_HOME="$HOME/.config" local_report
grep -Fx 'Global: ~/.config/codex-sync/ignore [disabled]' "$tmp/out"
if grep -Fq 'hidden-global/' "$tmp/out"; then exit 1; fi
: >"$HOME-sibling/my-app/.codexignore"
cd "$HOME-sibling/my-app"
XDG_CONFIG_HOME="$HOME-sibling/config" local_report
grep -Fx "Sync root: $HOME-sibling/my-app" "$tmp/out"
grep -Fx "Global: $HOME-sibling/config/codex-sync/ignore" "$tmp/out"
ok 'HOME display abbreviation respects boundaries; empty and disabled sources retain headers'
# Inspection works with neither SSH nor rsync available on PATH.
mkdir "$tmp/local-only"
ln -s "$(command -v bash)" "$tmp/local-only/bash"
PATH="$tmp/local-only" run inspect
[[ ! -e $LOG.ssh && ! -e $LOG.rsync ]]
ok 'inspect requires neither SSH nor rsync binaries'
