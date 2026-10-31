#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
mkdir -p "$tmp/parent space/near/demo" "$tmp/launch"
cd "$tmp/parent space/near/demo"
printf 'parent/\n' >"$tmp/parent space/.codexignore"
printf 'nearest/\n' >"$tmp/parent space/near/.codexignore"
touch .codexignore
for direction in push pull; do
	run "$direction"
	has "--exclude-from=$PWD/.codexignore"
	if has "--exclude-from=$tmp/parent space/near/.codexignore"; then exit 1; fi
done
ok 'local empty ignore wins over parent files in both directions'
rm .codexignore
for direction in push pull; do
	run "$direction"
	has "--exclude-from=$tmp/parent space/near/.codexignore"
	has "$tmp/parent space/near/demo/"
	has 'codex:~/demo/'
	if has "--exclude-from=$tmp/parent space/.codexignore"; then exit 1; fi
done
ok 'nearest inherited ignore wins, preserving spaces'
rm "$tmp/parent space/near/.codexignore"
run push
has "--exclude-from=$tmp/parent space/.codexignore"
ok 'walks multiple local parent directories'
ln -s "$tmp/parent space/near/demo" "$tmp/launch/linked"
cd "$tmp/launch/linked"
run push
has "--exclude-from=$tmp/parent space/.codexignore"
has "$tmp/parent space/near/demo/"
has 'codex:~/demo/'
ok 'symlinked cwd searches physical parents and preserves the cwd transfer root'
cd "$tmp/parent space/near/demo"
for direction in push pull; do
	mkdir .codexignore
	reject "$direction"
	[[ ! -e $LOG.ssh ]]
	rmdir .codexignore
	ln -s "$tmp/missing-ignore" .codexignore
	reject "$direction"
	[[ ! -e $LOG.ssh ]]
	rm .codexignore
	printf '!\n' >"$tmp/parent space/.codexignore"
	reject "$direction"
	[[ ! -e $LOG.ssh ]]
	printf 'parent/\n' >"$tmp/parent space/.codexignore"
done
ok 'invalid nearest entries and inherited clearing rules fail before SSH or rsync'
rm "$tmp/parent space/.codexignore"
# Do not modify shared ancestor files just to manufacture a missing-file case.
if [[ ! -e /tmp/.codexignore && ! -L /tmp/.codexignore && ! -e /.codexignore && ! -L /.codexignore ]]; then
	for direction in push pull; do
		reject "$direction"
		[[ ! -e $LOG.ssh ]]
		grep -Fq 'searched local project and parents' "$tmp/err"
	done
	ok 'no ignore through filesystem root fails before SSH or rsync'
else
	printf 'skip - no-file case requires no shared ancestor ignore\n'
fi
