#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
cd "$tmp/work/demo"
"$repo/bin/cpush" --dry-run >"$tmp/out" 2>"$tmp/err"
has --dry-run
"$repo/bin/cpull" --no-delete >"$tmp/out" 2>"$tmp/err"
mapfile -t args <"$LOG.rsync"
[[ ${args[-2]} == 'codex:~/demo/' ]]
"$repo/bin/codex-sync" --help >"$tmp/out"
[[ $(cat "$tmp/out") == $'Usage: codex-sync <push|pull> [--dry-run] [--no-delete]\n       codex-sync --help | --version\n\nSync root: directory containing the nearest .codexignore in physical cwd or parents.\nIn that file, # codex-sync: no-global-ignore disables global ignore rules.' ]]
"$repo/bin/codex-sync" --version >"$tmp/out"
[[ $(cat "$tmp/out") == 'codex-sync 0.1.0' ]]
ok 'wrappers forward options, help and version work'
