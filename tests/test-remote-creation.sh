#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
cd "$tmp/work/demo"
# Execute the actual SSH command against an isolated fake remote HOME.
export REMOTE_HOME="$tmp/remote ' home"
mkdir -p "$REMOTE_HOME"
cat >"$tmp/mock/ssh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$2" >>"$LOG.calls"
case $2 in
mkdir*)
	[[ ${FAIL_AT:-} != mkdir ]] || exit 1
	HOME=$REMOTE_HOME bash -c "$2"
	touch "$LOG.created"
	;;
*)
	[[ ${FAIL_AT:-} != check ]] || exit 255
	if [[ -e $LOG.created && ${FAIL_AT:-} == recheck ]]; then exit 1; fi
	HOME=$REMOTE_HOME bash -c "$2"
	;;
esac
MOCK
chmod +x "$tmp/mock/ssh"
reset_remote() {
	rm -rf -- "$REMOTE_HOME/demo"
	rm -f "$LOG.calls" "$LOG.created" "$LOG.rsync"
	unset FAIL_AT
}
no_creation() {
	[[ ! -e $LOG.created && ! -e $LOG.rsync ]]
	if grep -q '^mkdir' "$LOG.calls"; then exit 1; fi
}
mkdir "$REMOTE_HOME/demo"
run push
[[ -e $LOG.rsync && $(wc -l <"$LOG.calls") == 1 ]]
has 'codex:~/demo/'
ok 'existing remote destination transfers without creation'
reset_remote
reject push <<<y
grep -Fq noninteractive "$tmp/err"
no_creation
for direction in push pull; do
	reject "$direction" --dry-run <<<y
	no_creation
done
reject pull <<<y
no_creation
export FAIL_AT=check
reject push
no_creation
ok 'noninteractive, dry-run, pull and SSH failures never create or transfer'
reset_remote
touch "$REMOTE_HOME/demo"
reject push
no_creation
rm "$REMOTE_HOME/demo"
ln -s "$REMOTE_HOME/missing" "$REMOTE_HOME/demo"
reject push
no_creation
reset_remote
ln -s "$REMOTE_HOME" "$REMOTE_HOME/demo"
reject push
no_creation
reset_remote
ok 'files, dangling symlinks and unsafe aliases do not offer creation'
if ! command -v script >/dev/null; then
	printf 'skip - interactive remote creation tests require util-linux script\n'
	exit 0
fi
export SYNC_COMMAND=$repo/bin/codex-sync SYNC_DIRECTION=push SYNC_OPTION=''
cat >"$tmp/mock/remote-runner" <<'RUNNER'
#!/usr/bin/env bash
if [[ -n $SYNC_OPTION ]]; then
	exec "$SYNC_COMMAND" "$SYNC_DIRECTION" "$SYNC_OPTION"
fi
exec "$SYNC_COMMAND" "$SYNC_DIRECTION"
RUNNER
chmod +x "$tmp/mock/remote-runner"
terminal() {
	printf '%s' "$1" | script -q -e -c remote-runner /dev/null >"$tmp/terminal"
}
for answer in $'\n' $'n\n' $'no\n' $'garbage\n' $'\004'; do
	reset_remote
	if terminal "$answer"; then exit 1; fi
	grep -Fq '[y/N]' "$tmp/terminal"
	no_creation
done
ok 'default, negative, unknown and EOF responses decline'
for answer in y Y yes YES Yes; do
	reset_remote
	terminal "$answer"$'\n'
	[[ -d $REMOTE_HOME/demo && -e $LOG.created && -e $LOG.rsync ]]
	[[ $(wc -l <"$LOG.calls") == 3 ]]
	has --delete
	has 'codex:~/demo/'
done
ok 'accepted answers create a flat directory and revalidate before normal push'
for failure in mkdir recheck; do
	reset_remote
	export FAIL_AT=$failure
	if terminal $'y\n'; then exit 1; fi
	[[ ! -e $LOG.rsync ]]
done
ok 'mkdir and post-creation validation failures block rsync'
for scenario in dry-run pull check; do
	reset_remote
	case $scenario in
	dry-run) export SYNC_OPTION=--dry-run ;;
	pull) export SYNC_DIRECTION=pull ;;
	check) export FAIL_AT=check ;;
	esac
	if terminal $'y\n'; then exit 1; fi
	no_creation
	if grep -Fq '[y/N]' "$tmp/terminal"; then exit 1; fi
	export SYNC_OPTION='' SYNC_DIRECTION=push
done
ok 'interactive dry-run, pull and SSH failures never prompt or mutate'
