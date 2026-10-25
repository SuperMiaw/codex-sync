#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
cd "$tmp/work/demo"
run push
has "$tmp/work/demo/"
has 'codex:~/demo/'
has --delete
grep -q WARNING "$tmp/err"
[[ $(head -n 1 "$LOG.ssh") == codex ]]
ok 'current directory without Git, default host, deletion warning, trailing slashes'
run pull --dry-run
has --dry-run
has --delete
mapfile -t args <"$LOG.rsync"
[[ ${args[-2]} == 'codex:~/demo/' && ${args[-1]} == "$tmp/work/demo/" ]]
ok 'pull reverses endpoints and dry-run previews deletion'
run push --no-delete
if has --delete; then exit 1; fi
[[ ! -s $tmp/err ]]
ok 'no-delete removes deletion and warning'
