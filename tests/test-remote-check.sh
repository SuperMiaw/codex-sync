#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
# Execute the actual remote validation expression in a temporary mock remote home.
cd "$tmp/work/demo"
run push
mapfile -t ssh_args <"$LOG.ssh"
mkdir -p "$tmp/remote/demo"
HOME=$tmp/remote bash -c "${ssh_args[1]}"
rmdir "$tmp/remote/demo"
if HOME=$tmp/remote bash -c "${ssh_args[1]}"; then exit 1; fi
ln -s "$tmp/remote" "$tmp/remote/demo"
if HOME=$tmp/remote bash -c "${ssh_args[1]}"; then exit 1; fi
ok 'remote validation checks existence and refuses home aliases'
