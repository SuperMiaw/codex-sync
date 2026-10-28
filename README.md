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
| `project-folders` | Additional local search directories, one per line | `~/projects` |
| `ignore` | Global rsync exclusion patterns, one per line | `*.log` |

Create the configuration directory before adding files. In `project-folders`, use existing absolute paths or the `~/` shortcut; spaces within paths are supported. Blank lines and lines starting with `#` are ignored.

## Usage

Both local and remote project directories must already exist. With no project argument, the current directory is the project and its basename is the remote project name. With a name, lookup checks `./<name>` first, then `project-folders` in order. The remote directory is always `~/<name>` on the configured host.

Use a project name, not a path. Names may contain ASCII letters, digits, underscores, hyphens, and internal dots. Synchronizing the filesystem root or your home directory is prohibited.

```bash
cpush                        # Push the current project
cpull my-project             # Pull a named project
cpush --dry-run              # Preview changes, including planned deletions
cpull --no-delete my-project  # Pull while preserving destination-only files
```

Both wrappers accept `--dry-run` and `--no-delete`, which can be combined. Equivalent commands are `codex-sync push` and `codex-sync pull`; use `codex-sync --help` for help.

**Both push and pull delete destination-only files by default. Deletions may be permanent.** Preview with `--dry-run` before syncing, or use `--no-delete` to preserve destination-only files. Excluded destination files are preserved.

## .codexignore and secrets

Every local project needs a readable `.codexignore` file in its directory or a parent, even for pulls. An empty file is valid. Only the nearest file is used; an invalid nearest file prevents synchronization.

For example, create `.codexignore` in your project with:

```text
.env
.env.*
*.pem
*.key
node_modules/
build/
```

Patterns use rsync exclusion syntax relative to the project being transferred, including when inherited from a parent. They apply in both directions and combine with the optional global `ignore` file. The list-clearing `!` rule is not allowed.

Only `.git/`, `.ssh/`, and `.codexignore` are automatically excluded. **Other credentials, private keys, environment files, and secrets are not automatically detected or excluded.** Review your project, add appropriate exclusions, and preview with `cpush --dry-run`. Exclusion rules and dry runs do not guarantee that secrets cannot be transferred.

## Uninstallation

From the source directory:

```bash
./uninstall.sh
```

Removes installed commands matching the current source version and preserves modified or unrelated commands. Configuration and project `.codexignore` files are preserved.
