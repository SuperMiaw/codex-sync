#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
cd "$tmp/work"
for name in '' . .. ../demo /demo 'bad name' 'x;touch' '.hidden' 'trailing.'; do
	reject push "$name"
	[[ ! -e $LOG.ssh ]]
done
mkdir -p "$tmp/work/a-b_c.2"
touch "$tmp/work/a-b_c.2/.codexignore"
cd "$tmp/work"
run push a-b_c.2
reject push absent
reject push demo extra
reject push --unknown
ok 'valid internal dots and invalid names, missing project, bad arguments'
printf 'relative/path\n' >"$XDG_CONFIG_HOME/codex-sync/project-folders"
reject push demo
[[ ! -e $LOG.ssh ]]
printf '/nonexistent-codex-sync-test-root\n' >"$XDG_CONFIG_HOME/codex-sync/project-folders"
reject push demo
rm "$XDG_CONFIG_HOME/codex-sync/project-folders"
for host in '-oProxyCommand=x' 'host name' 'host;echo' ''; do
	printf '%s\n' "$host" >"$XDG_CONFIG_HOME/codex-sync/target-host"
	reject push demo
	[[ ! -e $LOG.ssh ]]
done
rm "$XDG_CONFIG_HOME/codex-sync/target-host"
ok 'invalid configured roots and SSH destinations rejected before SSH'
