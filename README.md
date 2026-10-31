# codex-sync

Synchronize existing local project directories with matching directories on a remote host over SSH and rsync.

**Requirements:** Debian/Linux, Bash, OpenSSH, and rsync. The remote host must be accessible over SSH and have rsync installed.

## Installation

Download `codex-sync-X.Y.Z.run` from this repository's **Releases** page, then run it (replace `X.Y.Z` with the release version):

```bash
chmod +x codex-sync-X.Y.Z.run
./codex-sync-X.Y.Z.run
```

Alternatively, from the source directory:

```bash
./install.sh
```

Both methods use the same installer and copy the commands into `~/.local/bin` without `sudo` or changes to your shell configuration.

Ensure that directory is in your `PATH`:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Configuration

Optional configuration files live in `${XDG_CONFIG_HOME:-$HOME/.config}/codex-sync/`:

| File | Purpose | Example contents |
|---|---|---|
| `target-host` | SSH host name or alias; defaults to `codex` | `my-sandbox` |
| `ignore` | Global rsync exclusion patterns, one per line | `*.log` |

### target-host

It is recommanded to use "~/.ssh/config" for simplify and an ssh agent like [danielrobbins/keychain](danielrobbins/keychain).

Exemple:
```
Host codex
  HostName 192.168.254.1
  Port 22
  User codex
```

### ignore

You can use a global `ignore` in addition to mandatory local `.codexignore`.

See [samples/ignore](samples/ignore) for example global patterns. Samples are not activated automatically; review them for your own files.

## Usage

```bash
cpush                        # Push the current project folder
cpull                        # Pull the current project folder
cpush --dry-run              # Preview changes, including planned deletions
cpull --no-delete            # Pull while preserving destination-only files
codex-sync inspect           # Show local exclusion rules and their sources
```

**Both push and pull delete destination-only files by default. Deletions may be permanent.** Preview with `--dry-run` before syncing, or use `--no-delete` to preserve destination-only files. Excluded destination files are preserved.

## .codexignore and secrets

Every project must have an explicit file `.codexignore`, even for pulls. For commodity, like `git` it will resolved if it exist in parent folder.

Patterns use rsync exclusion syntax relative to the synchronization root. Exclusion can only be added; by design the list-clearing `!` rule is not allowed.

Global ignore rules can be disabled, add `# codex-sync: no-global-ignore` on its own line in the project `.codexignore`. Surrounding spaces or tabs are allowed. This directive is metadata; ordinary rules in the same file and the built-in exclusions still apply.

`codex-sync inspect` shows the synchronization root and sorted exclusion rules grouped by source. Use `cpush --dry-run` to preview a transfer.

Only `.git/`, `.ssh/`, and `.codexignore` are automatically excluded. **Other credentials, private keys, environment files, and secrets are not automatically detected or excluded.** Review your project, add appropriate exclusions, and preview with `cpush --dry-run`. Exclusion rules and dry runs won't verify that secrets cannot be transferred, it's your own responsability.

## Uninstallation

From the source directory:

```bash
./uninstall.sh
```

Removes regular installed commands carrying the codex-sync header, including modified copies. Unrelated entries and symlinks are preserved with a warning and a nonzero exit status. Configuration and project `.codexignore` files are preserved by default.

Use `./uninstall.sh --purge` to also offer removal of `${XDG_CONFIG_HOME:-$HOME/.config}/codex-sync` with terminal confirmation; command removal happens before the prompt. Project `.codexignore` files are preserved.
