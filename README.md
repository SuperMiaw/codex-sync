# codex-sync

Synchronize existing local project directories with matching directories on a remote host over SSH and rsync. Use `cpush` for local → remote and `cpull` for remote → local.

**Requirements:** Debian/Linux, Bash, OpenSSH, and rsync. The remote host must be accessible over SSH and have rsync installed.

## Installation

From the source directory:

```bash
./install.sh
```

Installs `codex-sync`, `cpush`, and `cpull` into `~/.local/bin` without sudo or changes to your shell configuration. Ensure that directory is in your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Replacing different existing commands requires confirmation; use `./install.sh --force` for noninteractive replacement.

## Configuration

Optional configuration files live in `${XDG_CONFIG_HOME:-$HOME/.config}/codex-sync/`:

| File | Purpose | Example contents |
|---|---|---|
| `target-host` | SSH host name or alias; defaults to `codex` | `my-sandbox` |
| `ignore` | Global rsync exclusion patterns, one per line | `*.log` |

Create the configuration directory before adding files.

## Usage

Both local and remote project directories must already exist. Run from the local project directory or any subdirectory. The nearest `.codexignore` found in the physical current directory or its parents marks the synchronization root; that directory’s basename is the remote project name. The remote directory is always `~/<name>` on the configured host. Project-name arguments and global folder discovery are not supported.

The synchronization root's name may contain ASCII letters, digits, underscores, hyphens, and internal dots. Synchronizing the filesystem root or your home directory is prohibited.

```bash
cpush                        # Push the current project
cpull                        # Pull the current project
cpush --dry-run              # Preview changes, including planned deletions
cpull --no-delete            # Pull while preserving destination-only files
codex-sync inspect            # Show local exclusion rules and their sources
```

Both wrappers accept `--dry-run` and `--no-delete`, which can be combined. Equivalent commands are `codex-sync push` and `codex-sync pull`; use `codex-sync --help` for help.

**Both push and pull delete destination-only files by default. Deletions may be permanent.** Preview with `--dry-run` before syncing, or use `--no-delete` to preserve destination-only files. Excluded destination files are preserved.

## .codexignore and secrets

Every local project needs a readable `.codexignore` file in its directory or a parent, even for pulls. An empty file is valid. The search walks upward through physical parent directories. The entire directory containing the nearest `.codexignore` is transferred, even when you invoke the command from a subdirectory. Only the nearest file is used; an invalid nearest file prevents synchronization.

For example, create `.codexignore` in your project with:

```text
.env
.env.*
*.pem
*.key
node_modules/
build/
```

Patterns use rsync exclusion syntax relative to the synchronization root. They apply in both directions and combine with the optional global `ignore` file. The list-clearing `!` rule is not allowed.

To disable global ignore rules for this synchronization root in both directions, add `# codex-sync: no-global-ignore` on its own line in the selected `.codexignore`. Surrounding spaces or tabs are allowed. This directive is metadata; ordinary rules in the same file and the built-in exclusions still apply.

`codex-sync inspect` shows the synchronization root and exclusion rules under Built-in, Global, and Local headers, with paths shortened to `~` within your home directory. Global rules disabled by the directive show `[disabled]` instead of patterns; an absent global file shows only its path. Sections have no blank separator lines. Labels are bold and `[disabled]` is red only on terminal output when `NO_COLOR` is unset. Patterns are alphabetically sorted within each group. It runs locally without SSH or rsync and does not change files. It lists rules, not which files they match; use `cpush --dry-run` to preview a transfer.

Only `.git/`, `.ssh/`, and `.codexignore` are automatically excluded. **Other credentials, private keys, environment files, and secrets are not automatically detected or excluded.** Review your project, add appropriate exclusions, and preview with `cpush --dry-run`. Exclusion rules and dry runs do not guarantee that secrets cannot be transferred.

## Uninstallation

From the source directory:

```bash
./uninstall.sh
```

Removes installed commands matching the current source version and preserves modified or unrelated commands. Configuration and project `.codexignore` files are preserved.
