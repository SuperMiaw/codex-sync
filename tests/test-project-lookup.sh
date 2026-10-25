#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
printf '%s\n' "$tmp/root one" "$tmp/root2" >"$XDG_CONFIG_HOME/codex-sync/project-folders"
cd "$tmp/work"
run push demo
has "$tmp/work/demo/"
ok 'current-directory child wins over configured roots'
cd "$tmp"
run push demo
has "$tmp/root one/demo/"
ok 'configured roots preserve order and whitespace'
# Literal tilde tests the config parser, not shell expansion.
# shellcheck disable=SC2088
printf '%s\n' '# roots' '' '~/projects' >"$XDG_CONFIG_HOME/codex-sync/project-folders"
mkdir -p "$HOME/projects/demo"
touch "$HOME/projects/demo/.codexignore"
run push demo
has "$HOME/projects/demo/"
ok 'home shortcut, comments, and blank root lines'
