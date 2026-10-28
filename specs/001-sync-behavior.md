# 001 — Synchronization behavior

Status: agreed functional specification

## Goal

`codex-sync` synchronizes an existing local project directory with the matching existing directory on an SSH-accessible sandbox host, using rsync. It is independent of Git and does not create, provision, or deploy projects.

## Commands

- `codex-sync push [options] [project]`: local to remote.
- `codex-sync pull [options] [project]`: remote to local.
- `cpush` and `cpull`: executable wrappers forwarding all arguments to `codex-sync push` and `codex-sync pull`, respectively.
- Supported options: `--dry-run`, `--no-delete`, `--help`, `--version`.
- Preserve the simple `rsync -av` output by default; no extra `--verbose` or automatic `set -x`.

Runtime errors emitted by `codex-sync` are red and deletion warnings yellow only when stderr is a terminal and `NO_COLOR` is unset. Setting `NO_COLOR` to any value, including an empty value, disables color. Reset color after each diagnostic; add no color codes to redirected diagnostics. Existing human-facing messages gain semantic emoji prefixes: ❌ errors, ⚠️ warnings/prompts, ℹ️ transfer status, and ✅ installation/removal success. Preserve wording, streams, exit status, help/version output, and SSH/rsync output.

## Local project resolution

Without a project argument, use the current working directory itself as the project, regardless of whether it is a Git repository. Its basename is the remote project name. Do not walk upward to a Git root.

With a project-name argument:
1. Check for a directory named `./<project>` relative to the current working directory.
2. If not found, search `<root>/<project>` for each root listed in the configured `project-folders` file, in file order.
3. Use the first matching directory; fail clearly if none exists.

An explicit argument is a project **name**, not a path. Accept ASCII letters, digits, underscores, hyphens, and internal dots; reject `.`, `..`, path separators, and unsafe or empty names. Apply the same validation to the inferred basename. Do not require `.git`; require the local `.codexignore` as described below.

The project directory must already exist locally. Do not create it.

## Configuration

All user-level config files live under `${XDG_CONFIG_HOME:-$HOME/.config}/codex-sync/`.

### `project-folders`

An optional text file listing additional local search roots, one per line. Preserve order and spaces within paths. Ignore blank lines and lines beginning with `#`. Paths must be absolute and refer to existing directories; allow `~/` as a shortcut for the user's home directory. Validate all configured roots before project lookup, even when using the current directory or a matching local child. Reject or report invalid entries rather than interpreting relative paths against the current working directory. Missing file means no additional search roots.

### `target-host`

An optional file containing one SSH host name or alias. If missing, use `codex`. Validate that the value is a single nonempty SSH destination without embedded whitespace or shell syntax. This is a host selector, not an arbitrary SSH command.

### `ignore`

An optional global file of rsync-compatible exclude patterns. See below.

## Remote project resolution and validation

The remote project path is always `~/<project-name>` on the configured target host. The remote root is not independently configurable.

Before either push or pull, verify:
- the resolved local directory exists and is safe to synchronize;
- the nearest local `.codexignore` exists as a readable regular file before any SSH or rsync operation (an empty file is valid);
- the remote `~/<project-name>` directory exists via SSH.

If either is absent, stop with a clear error. Never create remote directories implicitly. Do not synchronize the filesystem root or the user's home directory as a project. Quote paths safely for both local commands and remote SSH/rsync contexts.

## Exclusions

Combine these three sources in both directions:
1. Exactly three non-overridable built-in exclusion patterns: `.git/`, `.ssh/`, and `.codexignore`. No other sensitive files or generated directories are excluded automatically.
2. Optional global `${XDG_CONFIG_HOME:-$HOME/.config}/codex-sync/ignore`.
3. Required nearest local `.codexignore`, found from the resolved local project upward.

For both push and pull, search the resolved **local** project directory first, then each physical parent through filesystem root, stopping at the first `.codexignore` entry (including dangling symlinks). With no project argument this begins at cwd; with a name it begins at the selected local project, not the launch directory. Never search remote paths. Only the nearest file is used; parent files are not combined. An invalid nearest entry fails validation rather than falling back. There is no explicit ignore-path override. Inherited patterns retain rsync semantics relative to the transfer root. Preserve the existing filename `.codexignore`. Fail clearly with a helpful message if the local `.codexignore` is missing, unreadable, or not a regular file. The global ignore file remains optional and does not replace `.codexignore`. Use rsync-compatible patterns rather than defining a new ignore syntax. Exclude the project ignore file itself from transfers. Do not use `--delete-excluded`; excluded destination files should remain protected under ordinary rsync deletion semantics.

The user is responsible for checking that no sensitive files or directories are transferred to the remote host. Document that credentials, private keys, environment files, and other secrets are not automatically excluded; recommend configuring `ignore` or `.codexignore` and previewing with `cpush --dry-run`. Exclusions and dry runs do not guarantee that secrets cannot be transferred.

Reject the rsync list-clearing `!` rule in either ignore file before any SSH or rsync operation so user patterns cannot remove the mandatory built-in exclusions.

## Deletion and preview

Default synchronization uses `rsync -av --delete` to mirror the selected source into the destination. Destination-only files **may be permanently deleted**.

- Display exactly `⚠️ Sync will delete destination-only files.` only for real sync operations with deletion enabled, without requiring interactive confirmation. Suppress the warning for `--dry-run` and `--no-delete`.
- `--no-delete` disables destination-only deletion.
- `--dry-run` performs a non-mutating rsync preview, including planned deletions when applicable.
- Preserve the behavior of `rsync -av` for ordinary file output.
- Never silently change the default to non-destructive sync.

The README must prominently warn that both push and pull can delete files at the destination.

## Installation and uninstall

`install.sh` copies `codex-sync`, `cpush`, and `cpull` to `$HOME/.local/bin`, without sudo, Fish setup, or editing shell startup files.

Preflight **all three** target paths before making changes:
- If absent, install.
- If identical to the source, proceed without confirmation.
- If different, list all collisions and ask once for confirmation, defaulting to No.
- In noninteractive mode, refuse collisions unless an explicit `--force` flag is supplied to the installer.
- Avoid partial updates where practical; do not overwrite unrelated files silently.

`uninstall.sh` removes installed commands carefully. It must not silently remove unrelated or modified executables. Preserve `${XDG_CONFIG_HOME:-$HOME/.config}/codex-sync/` and user project ignore files.

Installation is by **copy**, not symlink. Document how to ensure `~/.local/bin` is in `PATH`, without editing it automatically.

## Tests and acceptance

Use Bash tests with mocked SSH and rsync; no live remote required. Check:
- no-argument current-directory resolution without Git;
- named lookup in `./` before ordered configured roots;
- invalid project names and missing project errors;
- default and configured SSH target;
- required local ignore validation in both directions, including missing and empty files and no SSH or rsync on failure;
- nearest ignore lookup: local, inherited, nearest-wins, no file, physical parents, named selection independent of cwd, invalid entries and inherited list-clearing rules;
- optional global ignores, cumulative ignores, and built-in exclusions;
- rejection of list-clearing ignore rules;
- emoji message prefixes, unchanged help/version contracts, terminal diagnostic colors, redirected diagnostics, `NO_COLOR` including empty values, and unchanged SSH/rsync output (terminal checks require util-linux `script` and are skipped if unavailable);
- direction, source/destination trailing slash handling, and both-side existence checks;
- default `--delete`, `--no-delete`, and `--dry-run`, with the exact deletion warning only for real deleting syncs in both directions;
- installation collisions, force handling, and safe uninstall.

Run `bash -n`, shfmt, ShellCheck, and the test suite. Do not run real synchronization against user data without permission.
