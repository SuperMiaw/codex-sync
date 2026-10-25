#!/usr/bin/env bash
# Shared isolated fixtures and SSH/rsync mocks for each behavior test.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME=$tmp/home
export XDG_CONFIG_HOME=$tmp/config
export LOG=$tmp/log REMOTE_OK=1
mkdir -p "$HOME" "$XDG_CONFIG_HOME/codex-sync" "$tmp/mock" "$tmp/work/demo" "$tmp/root one/demo" "$tmp/root2/demo"
touch "$tmp/work/demo/.codexignore" "$tmp/root one/demo/.codexignore" "$tmp/root2/demo/.codexignore"
cat >"$tmp/mock/ssh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$LOG.ssh"
[[ $REMOTE_OK == 1 ]]
MOCK
cat >"$tmp/mock/rsync" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$LOG.rsync"
MOCK
chmod +x "$tmp/mock/ssh" "$tmp/mock/rsync"
export PATH=$tmp/mock:$PATH
count=0
ok() {
	count=$((count + 1))
	printf 'ok %d - %s\n' "$count" "$1"
}
has() { grep -F -x -- "$1" "$LOG.rsync" >/dev/null; }
run() { "$repo/bin/codex-sync" "$@" >"$tmp/out" 2>"$tmp/err"; }
reject() {
	rm -f "$LOG.rsync" "$LOG.ssh"
	if run "$@"; then
		printf 'Unexpected success: %s\n' "$*" >&2
		exit 1
	fi
	[[ ! -e $LOG.rsync ]]
}
