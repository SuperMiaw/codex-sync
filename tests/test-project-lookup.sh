#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
cd "$tmp/work/demo"
for direction in push pull; do
	run "$direction"
	has "$PWD/"
	has 'codex:~/demo/'
done
ok 'cwd without Git is the project in both directions'
printf 'relative/missing/root\n' >"$XDG_CONFIG_HOME/codex-sync/project-folders"
run push
has "$PWD/"
rm "$XDG_CONFIG_HOME/codex-sync/project-folders"
mkdir "$XDG_CONFIG_HOME/codex-sync/project-folders"
run pull
has "$PWD/"
ok 'obsolete project-folders is neither read nor validated'
cd "$tmp/work"
for direction in push pull; do
	reject "$direction" demo
	[[ ! -e $LOG.ssh ]]
	grep -Fq 'Unexpected argument: demo' "$tmp/err"
done
ok 'existing children and configured projects cannot be selected by name'
