#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
unset NO_COLOR
cd "$tmp/work/demo"
escape=$'\033'
run push
[[ $(cat "$tmp/err") == '⚠️ Sync will delete destination-only files.' ]]
[[ $(cat "$tmp/out") != *"$escape"* ]]
reject invalid
[[ $(cat "$tmp/err") == '❌ codex-sync: Expected push, pull or inspect (see --help)' ]]
ok 'redirected warnings and errors contain no color'

if ! command -v script >/dev/null; then
	printf 'SKIP: terminal color checks require util-linux script\n'
	exit 0
fi
# A small runner avoids interpolating fixture paths into script's shell command.
export COLOR_COMMAND=$repo/bin/codex-sync COLOR_STDOUT=$tmp/stdout COLOR_STDERR=$tmp/stderr
cat >"$tmp/mock/color-runner" <<'RUNNER'
#!/usr/bin/env bash
set -euo pipefail
case $COLOR_CASE in
warning) exec "$COLOR_COMMAND" push >"$COLOR_STDOUT" ;;
error) exec "$COLOR_COMMAND" invalid >"$COLOR_STDOUT" ;;
inspect) exec "$COLOR_COMMAND" inspect ;;
inspect-redirected) exec "$COLOR_COMMAND" inspect >"$COLOR_STDOUT" ;;
redirected) exec "$COLOR_COMMAND" push 2>"$COLOR_STDERR" ;;
esac
RUNNER
chmod +x "$tmp/mock/color-runner"
terminal() {
	export COLOR_CASE=$1
	script -q -e -c color-runner /dev/null >"$tmp/terminal"
}
terminal warning
[[ $(cat "$tmp/terminal") == *"${escape}[33m⚠️ Sync will delete destination-only files.${escape}[0m"* ]]
[[ $(cat "$tmp/stdout") != *"$escape"* ]]
if terminal error; then exit 1; fi
[[ $(cat "$tmp/terminal") == *"${escape}[31m❌ codex-sync: Expected push, pull or inspect (see --help)${escape}[0m"* ]]
ok 'terminal stderr colors warnings yellow and errors red with resets'
for value in '' 1; do
	export NO_COLOR=$value
	terminal warning
	[[ $(cat "$tmp/terminal") != *"$escape"* ]]
	if terminal error; then exit 1; fi
	[[ $(cat "$tmp/terminal") != *"$escape"* ]]
done
unset NO_COLOR
terminal redirected
[[ $(cat "$tmp/stderr") != *"$escape"* ]]
[[ $(cat "$tmp/terminal") != *"$escape"* ]]
ok 'NO_COLOR including empty values and redirected stderr disable color'

# Compare the whole terminal report to plain output with label and status escapes added.
for state in active absent disabled; do
	case $state in
	active) printf 'zebra/\nAlpha/\n' >"$XDG_CONFIG_HOME/codex-sync/ignore" ;;
	absent) rm "$XDG_CONFIG_HOME/codex-sync/ignore" ;;
	disabled) printf '# codex-sync: no-global-ignore\n' >.codexignore ;;
	esac
	run inspect
	[[ $(cat "$tmp/out") != *"$escape"* ]]
	# Only section labels and the directive-disabled Global suffix gain ANSI styling.
	sed -e "s/^\(Sync root:\|Built-in:\|Global:\|Local:\)/${escape}[1m\1${escape}[0m/" \
		-e "s/\[disabled\]/${escape}[31m[disabled]${escape}[0m/" "$tmp/out" >"$tmp/expected-color"
	terminal inspect
	tr -d '\r' <"$tmp/terminal" >"$tmp/actual-color"
	cmp "$tmp/expected-color" "$tmp/actual-color"
	for value in '' 1; do
		export NO_COLOR=$value
		terminal inspect
		tr -d '\r' <"$tmp/terminal" >"$tmp/plain-terminal"
		cmp "$tmp/out" "$tmp/plain-terminal"
	done
	unset NO_COLOR
	terminal inspect-redirected
	cmp "$tmp/out" "$tmp/stdout"

done
ok 'inspect bolds only labels and colors [disabled] on terminal stdout; NO_COLOR and redirection preserve plain text'

# External output must pass through verbatim, including its own escape codes.
cat >"$tmp/mock/rsync" <<'MOCK'
#!/usr/bin/env bash
printf 'rsync stdout\033[35munchanged\033[0m\n'
printf 'rsync stderr\033[36munchanged\033[0m\n' >&2
MOCK
cat >"$tmp/mock/ssh" <<'MOCK'
#!/usr/bin/env bash
printf 'ssh stdout\n'
printf 'ssh stderr\n' >&2
MOCK
run push --no-delete
[[ $(cat "$tmp/out") == $'ssh stdout\nℹ️ push: '*$'\nrsync stdout\033[35munchanged\033[0m' ]]
[[ $(cat "$tmp/err") == $'ssh stderr\nrsync stderr\033[36munchanged\033[0m' ]]
ok 'SSH and rsync output passes through unchanged'
