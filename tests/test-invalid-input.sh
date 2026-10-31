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
cd "$tmp/work/a-b_c.2"
run push
has 'codex:~/a-b_c.2/'
reject push absent
reject push extra
reject push --unknown
ok 'valid inferred internal dots and rejected positional arguments and unknown options'
for name in 'bad name' 'x;touch' '.hidden' 'trailing.'; do
	mkdir "$tmp/work/$name"
	touch "$tmp/work/$name/.codexignore"
	cd "$tmp/work/$name"
	reject push
	[[ ! -e $LOG.ssh ]]
done
cd "$tmp/work/a-b_c.2"
for host in '-oProxyCommand=x' 'host name' 'host;echo' ''; do
	printf '%s\n' "$host" >"$XDG_CONFIG_HOME/codex-sync/target-host"
	reject push
	[[ ! -e $LOG.ssh ]]
done
rm "$XDG_CONFIG_HOME/codex-sync/target-host"
ok 'unsafe inferred names and SSH destinations rejected before SSH'
