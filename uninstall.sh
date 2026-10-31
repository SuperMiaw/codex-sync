#!/usr/bin/env bash
set -euo pipefail

purge=false
case ${1:-} in
--purge)
	purge=true
	shift
	;;
esac

[[ $# == 0 ]] || {
	printf 'Usage: uninstall.sh [--purge]\n' >&2
	exit 2
}

managed_script() {
	local header marker
	{
		IFS= read -r header && IFS= read -r marker
	} <"$1" || return 1
	[[ $header == '#!/usr/bin/env bash' && $marker == '# codex-sync' ]]
}

status=0

for name in codex-sync cpush cpull; do
	path=$HOME/.local/bin/$name
	[[ -e $path || -L $path ]] || continue

	if [[ -f $path && ! -L $path ]] && managed_script "$path"; then
		rm -- "$path"
		printf '✅ Removed %s\n' "$path"
	else
		printf '⚠️ Ignored unrelated file: %s\n' "$path" >&2
		status=1
	fi
done

if $purge; then
	config=${XDG_CONFIG_HOME:-$HOME/.config}/codex-sync

	if [[ -d $config && ! -L $config ]]; then
		if [[ -t 0 ]]; then
			read -r -p "Remove configuration $config? [y/N] " answer || exit 1
			if [[ $answer == y || $answer == Y || $answer == yes ]]; then
				rm -r -- "$config"
				printf '✅ Removed %s\n' "$config"
			fi
		else
			printf '⚠️ Configuration removal requires confirmation.\n' >&2
			status=1
		fi
	fi
fi

exit "$status"
