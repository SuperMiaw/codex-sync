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
"$repo/bin/codex-sync" --version >"$tmp/out"
ok 'wrappers forward options, help and version work'
