#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME=$tmp/home
mkdir -p "$HOME" "$tmp/bin" "$tmp/work"
export UNINSTALL_COMMAND=$repo/uninstall.sh
cat >"$tmp/bin/purge-runner" <<'RUNNER'
#!/usr/bin/env bash
exec "$UNINSTALL_COMMAND" --purge
RUNNER
chmod +x "$tmp/bin/purge-runner"
export PATH=$tmp/bin:$PATH
cd "$tmp/work"

for mode in unset empty custom relative; do
	case $mode in
	unset) unset XDG_CONFIG_HOME ;;
	empty) export XDG_CONFIG_HOME='' ;;
	custom) export XDG_CONFIG_HOME="$tmp/custom config" ;;
	relative) export XDG_CONFIG_HOME='relative config' ;;
	esac
	config=${XDG_CONFIG_HOME:-$HOME/.config}/codex-sync
	other=$tmp/unselected/codex-sync
	if [[ $mode == custom || $mode == relative ]]; then
		other=$HOME/.config/codex-sync
	fi
	mkdir -p "$config" "$other"
	printf 'selected\n' >"$config/ignore"
	printf 'preserve\n' >"$other/ignore"
	if "$repo/uninstall.sh" --purge </dev/null >"$tmp/out" 2>"$tmp/err"; then exit 1; fi
	grep -Fq 'Configuration removal requires confirmation.' "$tmp/err"
	[[ -f $config/ignore && -f $other/ignore ]]
	if command -v script >/dev/null; then
		for answer in '' n; do
			printf '%s\n' "$answer" | script -q -e -c purge-runner /dev/null >"$tmp/terminal"
			grep -Fq "Remove configuration $config? [y/N]" "$tmp/terminal"
			[[ -f $config/ignore && -f $other/ignore ]]
		done
		printf 'y\n' | script -q -e -c purge-runner /dev/null >"$tmp/terminal"
		[[ ! -e $config && -f $other/ignore ]]
	else
		printf 'skip - interactive purge checks require util-linux script\n'
		rm -r -- "$config"
	fi
	# The selected entry itself must never be followed when it is a symlink.
	ln -s "$other" "$config"
	"$repo/uninstall.sh" --purge </dev/null >"$tmp/out" 2>"$tmp/err"
	[[ -L $config && -f $other/ignore && ! -s $tmp/err ]]
	rm -- "$config"
	printf 'ok - %s XDG purge resolution and safeguards\n' "$mode"
done
