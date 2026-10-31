#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
cd "$tmp/work/demo"
global=$XDG_CONFIG_HOME/codex-sync/ignore
marker=$PWD/.codexignore
mkdir nested
cd nested
for direction in push pull; do
	for directive in '# codex-sync: no-global-ignore' $' \t# codex-sync: no-global-ignore\t \r'; do
		printf '%s\nlocal-cache/\n%s\n*.log' "$directive" "$directive" >"$marker"
		# Even an invalid global file is unused when disabled.
		mkdir "$global"
		run "$direction"
		rmdir "$global"
		has --exclude-from=-
		if has "--exclude-from=$global"; then exit 1; fi
		[[ $(cat "$LOG.patterns") == $'local-cache/\n*.log' ]]
		has --exclude=.git/
		has --exclude=.ssh/
		has --exclude=.codexignore
		[[ $(grep -c '^--exclude=' "$LOG.rsync") == 3 ]]
		has "$tmp/work/demo/"
		has 'codex:~/demo/'
		if has --delete-excluded; then exit 1; fi
	done
	printf '!\n' >"$global"
	printf '# codex-sync: no-global-ignore' >"$marker"
	run "$direction"
	[[ ! -s $LOG.patterns ]]
	has --exclude-from=-
	REMOTE_OK=0 reject "$direction"
	[[ -e $LOG.ssh ]]
	printf '# codex-sync: no-global-ignore\nlocal-cache/\n' >"$marker"
	run "$direction"
	printf '!\n' >>"$marker"
	reject "$direction"
	[[ ! -e $LOG.ssh ]]
	rm "$global"
done
ok 'directive skips global validation, preserves local rules and built-ins, and uses inherited root in both directions'

printf 'global-cache/\n' >"$global"
for near_match in '# codex-sync: no-global-ignore extra' '# codex-sync: NO-GLOBAL-IGNORE' '#codex-sync: no-global-ignore' '# codex-sync:  no-global-ignore'; do
	printf '%s\n' "$near_match" >"$marker"
	run push
	has "--exclude-from=$global"
	has "--exclude-from=$marker"
done
ok 'only exact case-sensitive directive with surrounding whitespace matches'

printf '# codex-sync: no-global-ignore\nglobal-cache/\n' >"$global"
printf 'local-cache/\n' >"$marker"
run pull
has "--exclude-from=$global"
has "--exclude-from=$marker"
printf '# codex-sync: no-global-ignore\n' >"$tmp/work/.codexignore"
run push
has "--exclude-from=$global"
has "--exclude-from=$marker"
ok 'directive in global or unselected ancestor file has no effect'
