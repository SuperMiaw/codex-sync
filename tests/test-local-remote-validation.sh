#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
cd "$tmp/work/demo"
export REMOTE_OK=0
reject push
reject pull
[[ -e $LOG.ssh ]]
export REMOTE_OK=1
ok 'remote validation blocks both directions'
# A real marker ensures this exercises root safety, not missing-marker refusal.
touch "$HOME/.codexignore"
ln -s "$HOME" "$tmp/work/home-link"
cd "$tmp/work/home-link"
for direction in push pull; do
	reject "$direction"
	[[ ! -e $LOG.ssh ]]
	grep -Fq 'Refusing to synchronize filesystem root or home directory' "$tmp/err"
done
ok 'physical home alias is rejected locally in both directions'
