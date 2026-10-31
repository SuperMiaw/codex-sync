#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
if [[ -e /tmp/.codexignore || -L /tmp/.codexignore || -e /.codexignore || -L /.codexignore ]]; then
	printf 'skip - creation tests require no shared ancestor marker\n'
	exit 0
fi
mkdir -p "$tmp/project/nested"
cd "$tmp/project/nested"
cat >"$tmp/mock/git" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"$LOG.git"
case ${GIT_CASE:-absent} in
root) printf '%s\n' "$GIT_ROOT" ;;
file) printf 'preserve\n' >"$GIT_ROOT/.codexignore"; printf '%s\n' "$GIT_ROOT" ;;
 race) ln -s "$RACE_TARGET" "$GIT_ROOT/.codexignore"; printf '%s\n' "$GIT_ROOT" ;;
*) exit 1 ;;
esac
MOCK
chmod +x "$tmp/mock/git"
for direction in push pull; do
	reject "$direction" <<<y
	[[ ! -e $LOG.ssh && ! -e .codexignore ]]
	grep -Fq 'Noninteractive context' "$tmp/err"
done
reject inspect
[[ ! -e $LOG.ssh && ! -e .codexignore ]]
grep -Fq 'Required local project ignore file' "$tmp/err"
ok 'noninteractive affirmative input never creates or transfers; inspect stays read-only'
if ! command -v script >/dev/null; then
	printf 'skip - interactive creation tests require util-linux script\n'
	exit 0
fi
export SYNC_COMMAND=$repo/bin/codex-sync SYNC_DIRECTION=push
cat >"$tmp/mock/creation-runner" <<'RUNNER'
#!/usr/bin/env bash
exec "$SYNC_COMMAND" "$SYNC_DIRECTION" --dry-run
RUNNER
chmod +x "$tmp/mock/creation-runner"
terminal() {
	rm -f "$LOG.ssh" "$LOG.rsync"
	if printf '%s\n' "$1" | script -q -e -c creation-runner /dev/null >"$tmp/terminal"; then
		printf 'Unexpected success after missing marker\n' >&2
		exit 1
	fi
	[[ ! -e $LOG.ssh && ! -e $LOG.rsync ]]
	grep -Fq '[y/N]' "$tmp/terminal"
}
for answer in '' n no garbage; do
	terminal "$answer"
	[[ ! -e .codexignore ]]
done
ok 'empty, negative and unrecognized interactive responses decline by default'
terminal y
[[ -f .codexignore && ! -s .codexignore ]]
grep -Fq "Created empty $PWD/.codexignore" "$tmp/terminal"
grep -Fq 'Review sensitive files and exclusions, then rerun' "$tmp/terminal"
rm .codexignore
ok 'failed Git hint falls back to physical cwd and creates an empty marker then stops'
export GIT_CASE=root GIT_ROOT=$tmp/project SYNC_DIRECTION=pull
terminal yes
[[ -f $GIT_ROOT/.codexignore && ! -s $GIT_ROOT/.codexignore && ! -e .codexignore ]]
[[ $(cat "$LOG.git") == $(printf '%s\n' -C "$PWD" rev-parse --show-toplevel) ]]
rm "$GIT_ROOT/.codexignore"
ok 'pull suggests mocked Git worktree ancestor without transferring, including dry runs'
export GIT_CASE=file
terminal y
[[ $(cat "$GIT_ROOT/.codexignore") == preserve ]]
rm "$GIT_ROOT/.codexignore"
ok 'exclusive creation preserves a regular file introduced after lookup'
export GIT_CASE=race RACE_TARGET=$tmp/untouched
printf 'preserve\n' >"$RACE_TARGET"
terminal y
[[ -L $GIT_ROOT/.codexignore && $(cat "$RACE_TARGET") == preserve ]]
rm "$GIT_ROOT/.codexignore" "$RACE_TARGET"
terminal y
[[ -L $GIT_ROOT/.codexignore && ! -e $RACE_TARGET ]]
rm "$GIT_ROOT/.codexignore"
ok 'exclusive creation preserves both existing and dangling symlinks introduced after lookup'
# Missing Git binary: retain only Bash and script plus transfer mocks on PATH.
mkdir "$tmp/no-git"
for executable in bash script; do ln -s "$(command -v "$executable")" "$tmp/no-git/$executable"; done
unset GIT_CASE
if printf 'y\n' | PATH="$tmp/no-git" script -q -e -c "$tmp/mock/creation-runner" /dev/null >"$tmp/terminal"; then exit 1; fi
[[ -f .codexignore && ! -s .codexignore && ! -e $LOG.ssh && ! -e $LOG.rsync ]]
ok 'Git unavailable falls back to physical cwd'
