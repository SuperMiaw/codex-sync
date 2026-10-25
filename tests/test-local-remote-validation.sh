#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
cd "$tmp/work"
export REMOTE_OK=0
reject push demo
reject pull demo
[[ -e $LOG.ssh ]]
export REMOTE_OK=1
ok 'remote validation blocks both directions'
ln -s "$HOME" "$tmp/work/home-link"
ln -s / "$tmp/work/root-link"
reject push home-link
reject pull root-link
cd "$HOME"
reject push
cd /
reject pull
mkdir -p "$tmp/bad name"
cd "$tmp/bad name"
reject push
ok 'home/root symlinks and unsafe inferred names rejected locally'
