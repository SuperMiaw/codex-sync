#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
printf 'global-cache/\n' >"$XDG_CONFIG_HOME/codex-sync/ignore"
mkdir -p "$HOME/projects/demo"
printf 'local-cache/\n' >"$HOME/projects/demo/.codexignore"
"$repo/install.sh" >"$tmp/out"
[[ $(cat "$tmp/out") == "✅ Installed commands in $HOME/.local/bin" ]]
for name in codex-sync cpush cpull; do
	cmp "$repo/bin/$name" "$HOME/.local/bin/$name"
	[[ -x $HOME/.local/bin/$name && ! -L $HOME/.local/bin/$name ]]
done
"$repo/install.sh" </dev/null >"$tmp/out"
printf 'modified\n' >"$HOME/.local/bin/cpush"
printf 'unrelated\n' >"$HOME/.local/bin/cpull"
if "$repo/install.sh" </dev/null >"$tmp/out" 2>"$tmp/err"; then exit 1; fi
grep -q '^⚠️ Existing command collisions:' "$tmp/err"
grep -q '^❌ Noninteractive collision:' "$tmp/err"
grep -q '/cpush' "$tmp/err"
grep -q '/cpull' "$tmp/err"
[[ $(cat "$HOME/.local/bin/cpush") == modified ]]
ok 'copy install, identical reinstall, all collisions reported and refused'
"$repo/install.sh" --force >"$tmp/out" 2>"$tmp/err"
printf 'modified\n' >>"$HOME/.local/bin/cpush"
if "$repo/uninstall.sh" >"$tmp/out" 2>"$tmp/err"; then exit 1; fi
[[ -f $HOME/.local/bin/cpush && ! -e $HOME/.local/bin/codex-sync && ! -e $HOME/.local/bin/cpull ]]
[[ -f $XDG_CONFIG_HOME/codex-sync/ignore && -f $HOME/projects/demo/.codexignore ]]
"$repo/install.sh" --force >"$tmp/out" 2>"$tmp/err"
"$repo/uninstall.sh" >"$tmp/out"
grep -q "^✅ Removed $HOME/.local/bin/" "$tmp/out"
[[ ! -e $HOME/.local/bin/cpush ]]
ok 'forced replacement and safe uninstall preserve modified commands and config'
