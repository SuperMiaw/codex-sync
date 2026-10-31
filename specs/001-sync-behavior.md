# 001 — Synchronization behavior

Status: agreed functional specification

## Goal

`codex-sync` synchronizes an existing local project directory with the matching existing directory on an SSH-accessible sandbox host, using rsync. Git is optional and used only as a missing-marker creation hint; the tool can assist with creating a missing remote push destination as specified below; it does not provision workspaces.

## Commands

- `codex-sync push [options]`: local to remote.
- `codex-sync pull [options]`: remote to local.
- `codex-sync inspect`: read-only local inspection; accepts `--help` and `--version`, rejects transfer options and positional arguments. The former `ignore` subcommand is rejected; there is no alias.
- `cpush` and `cpull`: executable wrappers forwarding all arguments to `codex-sync push` and `codex-sync pull`, respectively.
- `--version` prints `codex-sync` followed by the manually maintained `VERSION` constant (currently `0.1.0`); routine edits do not change it.
- Supported options: `--dry-run`, `--no-delete`, `--help`, `--version`.
- Preserve the simple `rsync -av` output by default; no extra `--verbose` or automatic `set -x`.

Runtime errors emitted by `codex-sync` are red and deletion warnings yellow only when stderr is a terminal and `NO_COLOR` is unset. Setting `NO_COLOR` to any value, including an empty value, disables color. Reset color after each diagnostic; add no color codes to redirected diagnostics. Existing human-facing messages gain semantic emoji prefixes: ❌ errors, ⚠️ warnings/prompts, ℹ️ transfer status, and ✅ installation/removal success. Preserve wording, streams, exit status, version output, and SSH/rsync output. Help also describes marker-defined root resolution and assisted missing-marker creation.

## Local project resolution

Starting at the physical current working directory, traverse physical parents through filesystem root to find the nearest `.codexignore` entry. Its containing directory is the synchronization root for both push and pull, regardless of Git metadata. Transfer that entire directory, even when invoked from a nested subdirectory. Its basename is the remote project name, with no nested remote workspace path. Validate the resolved root and its basename rather than the invocation subdirectory.

Project-name and path arguments are rejected before SSH or rsync. There is no child-directory lookup or global folder discovery. Accept ASCII letters, digits, underscores, hyphens, and internal dots in the inferred basename; reject `.`, `..`, path separators, and unsafe or empty names. Do not require `.git`; require the local `.codexignore` as described below.

The project directory must already exist locally. Do not create it.

## Configuration

All user-level config files live under `${XDG_CONFIG_HOME:-$HOME/.config}/codex-sync/`.

The former `project-folders` file is unused: it is neither read nor validated.

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

If either is absent, stop without transferring except for the explicit assisted remote push creation below; a missing local marker can use the assisted creation flow below. Never create remote directories implicitly. Do not synchronize the filesystem root or the user's home directory as a project. Quote paths safely for both local commands and remote SSH/rsync contexts.

## Assisted missing remote destination creation

Only a real push may offer creation when SSH confirms that `~/<project-name>` has no entry (including no dangling symlink). The check returns status 3 for absence; other failures, including SSH transport failure, stop without prompting. Existing files, dangling symlinks, and unsafe directory aliases are errors.

Require both stdin and stderr to be terminals. Prompt explicitly with the host and destination and default No `[y/N]`; accept only `y`, `Y`, `yes`, `YES`, or `Yes`. Empty input, EOF and all other responses decline. Decline and noninteractive contexts stop nonzero without mkdir or rsync. On affirmation, use SSH to run a quoted `mkdir -- "$HOME/<project-name>"` without `-p`; creation failure (including a newly appeared entry) stops. Revalidate the directory through SSH after successful creation; only a successful check allows the normal push to proceed. No local directory is created. Host selection, flat remote layout, excludes, and deletion semantics are unchanged.

Pull never offers creation. Dry-run reports a missing remote destination and stops nonzero without prompting or mutating remote state, even on affirmative terminal input. This remote flow does not change the separate missing-local-marker assistance.

## Exclusions

Combine these sources in both directions (the directive below can disable only the global source):
1. Exactly three non-overridable built-in exclusion patterns: `.git/`, `.ssh/`, and `.codexignore`. No other sensitive files or generated directories are excluded automatically.
2. Optional global `${XDG_CONFIG_HOME:-$HOME/.config}/codex-sync/ignore`.
3. Required nearest local `.codexignore`, found from the physical invocation directory upward; its directory defines the local project.

For both push and pull, search the physical **local** invocation directory first, then each physical parent through filesystem root, stopping at the first `.codexignore` entry (including dangling symlinks). This begins at the physical current working directory. Never search remote paths. Only the nearest file is used; parent files are not combined. An invalid nearest entry fails validation rather than falling back. There is no explicit ignore-path override. Patterns retain rsync semantics relative to the marker-defined transfer root. Preserve the existing filename `.codexignore`. If the local `.codexignore` is missing, use the assisted creation flow below for push/pull; unreadable or non-regular entries fail clearly without offering creation. The global ignore file remains optional and does not replace `.codexignore`. Use rsync-compatible patterns rather than defining a new ignore syntax. Exclude the project ignore file itself from transfers. Do not use `--delete-excluded`; excluded destination files should remain protected under ordinary rsync deletion semantics.

The user is responsible for checking that no sensitive files or directories are transferred to the remote host. Document that credentials, private keys, environment files, and other secrets are not automatically excluded; recommend configuring `ignore` or `.codexignore` and previewing with `cpush --dry-run`. Exclusions and dry runs do not guarantee that secrets cannot be transferred.

Reject the rsync list-clearing `!` rule in either ignore file before any SSH or rsync operation so user patterns cannot remove the mandatory built-in exclusions.

The selected local `.codexignore` may contain the metadata directive `# codex-sync: no-global-ignore`. For recognition, remove one terminal carriage return (supporting CRLF as well as LF), then trim only leading and trailing ASCII spaces and tabs. The remaining line must match that literal exactly, case-sensitively, with no additional text or changes to internal whitespace. A final line without a newline is supported. Repeated matching directives are idempotent. Other lines retain ordinary rsync semantics.

If any line matches, skip the global ignore file entirely, including existence/readability and list-clearing validation, for both push and pull. Remove matching metadata lines from the project patterns supplied to rsync; keep every other project rule active, including rejection of the list-clearing `!` rule. Built-in exclusions remain unchanged and mandatory. Directives in the global file or an unselected ancestor marker have no special meaning. Root lookup and both-side validation remain unchanged.

## Assisted missing-marker creation

Only push/pull (including dry runs) offer assistance when the entire physical cwd-to-root search finds no `.codexignore` entry. Invalid existing entries retain validation errors without prompting. Before any host configuration, SSH or rsync operation, suggest the physical Git worktree root from optional `git -C <physical-cwd> rev-parse --show-toplevel`, if it resolves to an existing physical ancestor; otherwise suggest physical cwd. Git failure or absence is harmless. Git never changes marker lookup or transfer root semantics.

Warn about reviewing sensitive files and exclusions; an empty marker does not protect secrets. Require both stdin and stderr to be terminals before prompting; otherwise fail nonzero without creation. Reject unsafe root/home locations and invalid suggested root names. Prompt explicitly with default No `[y/N]`; accept only `y`, `Y`, `yes`, `YES`, or `Yes`. Empty input, EOF and all other answers decline. On affirmation, exclusively create an empty `.codexignore` without overwriting any existing entry, including dangling symlinks or entries introduced after lookup. Creation failure is an error. Never create directories. Always stop nonzero without SSH or rsync, including after successful creation, and tell the user to review exclusions and rerun. Inspect remains read-only and fails normally for missing markers.

## Local inspection

`codex-sync inspect` shares physical root lookup, root/name safety checks, ignore source selection, directive parsing, and ignore file validation with push/pull. It does not read or validate `target-host`, check remote directories, require SSH/rsync binaries, or invoke either command. It never creates files or directories.

After successful validation, print exactly this layout (with the selected paths and patterns):

```text
Sync root: ~/my-app
Built-in:
  .codexignore
  .git/
  .ssh/
Global: ~/.config/codex-sync/ignore [disabled]
Local: ~/my-app/.codexignore
  .env
  node_modules/
```

Use the exact labels shown with no blank separator lines, with two spaces before each rule. Always show Global and Local paths on their header lines, including empty sources. An absent optional global file has no status or rule rows. Only a global source disabled by the local directive has the suffix ` [disabled]`; do not inspect that file, even for existence, or display its patterns. Color only `[disabled]` red, with a reset immediately afterward, when stdout is a terminal and `NO_COLOR` is unset. Any value of `NO_COLOR`, including empty, disables color. Under the same ANSI condition, render only the labels `Sync root:`, `Built-in:`, `Global:`, and `Local:` in bold, resetting immediately after each label. Paths and rules remain unstyled. Do not print active statuses, origin tags, duplicate source/effective-rule sections, or a footer.

The root is the physical directory containing the nearest marker. For display only, replace HOME itself with `~` and its strict descendants with `~/...`; do not abbreviate paths that merely share a HOME prefix. Actual paths and synchronization behavior remain unchanged.

Show effective rules once under each origin in built-in/global/local order, sorting alphabetically within each origin (deterministic C-locale byte order), preserving duplicates. Actual rsync rule order and parsing are unchanged. Omit empty lines, lines containing only a carriage return, comments beginning with `#` or `;`, and matching local metadata directives; display other rule text literally, without trimming. Errors use the existing stderr diagnostics and nonzero exit status. This lists configured exclusion rules without evaluating file matches; use a sync dry run for transfer previews.

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
- Use `cmp -s` for existing regular files; identical executables are not rewritten. Identical files lacking executable permission receive mode 755 without rewriting their contents.
- A differing regular file is a managed script only when its first two lines are exactly `#!/usr/bin/env bash` and `# codex-sync`. All three installable scripts carry this marker immediately after the shebang. This marker is an identification convention, not proof of authenticity.
- List managed updates and unrelated collisions separately. Ask once per nonempty group: update managed scripts, then explicitly replace unrelated files or symlinks, each defaulting to No `[y/N]`. Accept only `y`, `Y`, `yes`, `YES`, or `Yes`; EOF and other answers decline.
- Require terminal stdin and stderr for confirmations; otherwise fail without changes unless `--force` explicitly overrides both confirmations.
- Symlinks (including dangling links and links to directories) are always collisions, never managed or identical; replacement replaces the link, not its referent. Other non-regular entries and directories fail even with `--force`.
- Complete all preflight checks and confirmations before modifying any target. Stage all changed commands with mode 755 before moving them into place; unchanged executables retain their permissions and identity. The final three-file replacement is not atomic as a group.
- Never manage user configuration files.

`uninstall.sh` removes installed commands carefully. It must not silently remove unrelated or modified executables. Preserve `${XDG_CONFIG_HOME:-$HOME/.config}/codex-sync/` and user project ignore files.

Installation is by **copy**, not symlink. Document how to ensure `~/.local/bin` is in `PATH`, without editing it automatically.

## Tests and acceptance

Use Bash tests with mocked SSH and rsync; no live remote required. Check:
- no-argument current-directory resolution without Git;
- rejection of project-name/path arguments and absence of child/global folder lookup;
- stale or invalid `project-folders` files have no effect;
- invalid project names and missing project errors;
- default and configured SSH target;
- assisted missing-marker creation: affirmative/negative/default responses, noninteractive affirmative input, optional mocked Git worktree hint and failure/unavailable fallback, exclusive regular-file and symlink protection, dry-run stop behavior, unchanged inspect errors, and no SSH/rsync; interactive tests require util-linux `script`;
- required local ignore validation in both directions, including missing and empty files and no SSH or rsync on failure;
- nearest ignore lookup: local, inherited, nearest-wins, no file, physical parents, nested invocation transferring the marker directory in both directions, flat remote basename naming, nested markers, validation of marker roots rather than invocation names, unsafe home roots, invalid entries and inherited list-clearing rules;
- optional global ignores, cumulative ignores, and built-in exclusions;
- local no-global-ignore directive in both directions: exact case-sensitive matching, surrounding spaces/tabs, LF/CRLF, duplicate directives, final lines without a newline, metadata removal with ordinary rules retained, skipped invalid global files, retained local list-clearing rejection and built-ins, inherited roots, and no effect from near matches or directives in global/unselected ancestor files;
- local inspection grouping, source paths and inherited roots, XDG configuration, exact compact layout, empty/absent global headers and directive-only [disabled] suffix, HOME abbreviation with strict path boundaries, CRLF and final-line directive handling, shared invalid-file/list-clearing validation, argument rejection, display-only alphabetical ordering within each origin, duplicates, stdout terminal bold section labels, red [disabled] status, and NO_COLOR gating, empty active sources, literal whitespace and ordinary global directive-like rules, rejection of the removed ignore subcommand, and no SSH/rsync calls even with invalid target-host configuration;
- rejection of list-clearing ignore rules;
- emoji message prefixes, help describing marker-defined root resolution, unchanged version output, terminal diagnostic colors, redirected diagnostics, `NO_COLOR` including empty values, and unchanged SSH/rsync output (terminal checks require util-linux `script` and are skipped if unavailable);
- direction, source/destination trailing slash handling, and both-side existence checks;
- assisted remote push creation with mocked SSH/rsync: existing and absent entries, affirmative/default/negative/EOF answers, noninteractive refusal, dry-run and pull refusal, SSH/check/mkdir/revalidation failures, flat paths, shell-safe remote HOME quoting, and no transfer before successful creation and revalidation; terminal cases require util-linux `script`;
- default `--delete`, `--no-delete`, and `--dry-run`, with the exact deletion warning only for real deleting syncs in both directions;
- installation copies and header markers, unchanged-file identity, managed updates, unrelated/header near-match collisions, symlinks, mixed-set preflight and default/negative/EOF confirmation, noninteractive and force handling, staged failures, executable permissions, and safe uninstall; terminal installer cases require util-linux `script`.

Run `bash -n`, shfmt, ShellCheck, and the test suite. Do not run real synchronization against user data without permission.
