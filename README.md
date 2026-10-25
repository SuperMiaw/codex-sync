# codex-sync

A lightweight Bash CLI to synchronize local projects with a remote Codex sandbox using SSH and rsync.

- Bidirectional synchronization with `cpush` and `cpull`
- No Git dependency
- Configurable SSH target and project search paths
- Project-specific and global exclusions
- No remote provisioning

**Requirements:** Debian/Linux, Bash, OpenSSH and rsync.

## Installation

```bash
./install.sh
```

Installs three commands into `~/.local/bin`:

- `codex-sync` — main CLI
- `cpush` — push local files to the remote host
- `cpull` — pull remote files to the local project

Make sure `~/.local/bin` is in your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Installation does not require sudo or modify your shell configuration. Existing commands are not overwritten without confirmation. Use `./install.sh --force` for noninteractive replacement.

## Usage

Both local and remote project directories must already exist. `codex-sync` does not create them.

Each local project must contain a `.codexignore` file, even if empty:

```bash
touch .codexignore
```

### Synchronize the current project

```bash
cpush                 # Local → remote
cpull                 # Remote → local
```

### Synchronize a named project

```bash
cpush my-project
cpull my-project
```

### Preview changes

```bash
cpush --dry-run
cpull --dry-run
```

### Synchronize without deleting destination files

```bash
cpush --no-delete
cpull --no-delete
```

The equivalent main CLI commands are `codex-sync push` and `codex-sync pull`. Other options: `--help`, `--version`.

**Important:** Synchronization uses `rsync -av --delete` by default. Files present only at the destination may be permanently deleted. Preview with `--dry-run` first.

### Project resolution

Without an argument, the current directory is used as the project.

With a project name, `codex-sync` searches in this order:

1. `./<project-name>`
2. Each directory configured in `project-folders`

The first match is used. The corresponding remote directory is always:

```text
<target-host>:~/<project-name>/
```

Project names cannot contain paths or unsafe characters. Synchronizing the filesystem root or home directory is prohibited.

## Configuration

Configuration files live in `~/.config/codex-sync/`, or under `$XDG_CONFIG_HOME/codex-sync/` when configured.

All three configuration files are optional.

| File | Purpose |
|---|---|
| `target-host` | SSH hostname or alias; defaults to `codex` |
| `project-folders` | Additional local directories to search |
| `ignore` | Global rsync exclusion patterns |

### Example: target-host

```text
codex
```

An SSH alias from `~/.ssh/config` can be used.

### Example: project-folders

```text
~/projects
~/work
/opt/work projects
```

One directory per line. Paths must be absolute, except for the supported `~/` shortcut. Empty lines and comments beginning with `#` are ignored.

### Example: ignore

```text
*.log
.cache/
```

These exclusions apply to every project, in addition to its `.codexignore`.

## Exclusions & Security

**Every local project must contain a readable `.codexignore` file.** This applies to both push and pull operations.

An empty file is accepted, but a missing or unreadable file prevents synchronization.

Only three patterns are excluded automatically:

```text
.git/
.ssh/
.codexignore
```

All other exclusions are your responsibility.

For example, a project's `.codexignore` might contain:

```text
.env
.env.*
*.pem
*.key
node_modules/
build/
```

The global `ignore` file and `.codexignore` use rsync exclusion patterns. Exclusions are cumulative and apply in both directions. The `!` rule that clears exclusions is not allowed.

### Sensitive data

**Review your project before pushing files to a remote environment.**

Credentials, private keys, environment files and other sensitive data are not automatically detected or excluded.

Use `.codexignore` to explicitly exclude sensitive content and `cpush --dry-run` to preview synchronization. A dry run and exclusion rules do not guarantee that sensitive files cannot be transferred.

### Deletion behavior

Both `cpush` and `cpull` can delete destination-only files because `--delete` is enabled by default. Use `--no-delete` when you want to preserve them.

Excluded destination files are not removed by the normal exclusion behavior.

Errors are displayed in red and deletion warnings in yellow when supported by the terminal. Colors are disabled for redirected diagnostics or when `NO_COLOR` is set. SSH and rsync output remains unchanged.

## Uninstallation

From the source directory:

```bash
./uninstall.sh
```

Only installed commands matching the current source version are removed. Modified or unrelated commands are preserved. Configuration files and project `.codexignore` files are never removed.
