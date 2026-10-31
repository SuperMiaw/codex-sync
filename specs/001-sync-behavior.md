# 001 — Synchronization behavior

Status: current implementation contract (including known test discrepancies below)

## Goal

`codex-sync` synchronizes a marker-defined local project with `~/<project-name>` on an SSH-accessible host using rsync. The assistance flows below can create a missing local marker or remote push destination; the tool does not provision workspaces. Git is optional and used only as a marker-creation location hint.

## Commands

- `codex-sync push [options]`: local to remote.
- `codex-sync pull [options]`: remote to local.
- `codex-sync inspect`: read-only local inspection; accepts `--help` and `--version`, rejects transfer options and positional arguments. All other subcommands, including `ignore`, are rejected.
- `cpush` and `cpull`: executable wrappers forwarding all arguments to `codex-sync push` and `codex-sync pull`, respectively.
- `--version` prints `codex-sync` followed by the manually maintained `VERSION` constant (currently `0.1.0`); routine edits do not change it.
- Supported options: `--dry-run`, `--no-delete`, `--help`, `--version`.
- No arguments prints usage to stderr and exits 2. Unknown commands/options and positional arguments fail with status 1.
- Help/version exit successfully as soon as encountered: top-level forms ignore trailing arguments; subcommand options are processed left to right, so an earlier invalid argument still fails. Repeated transfer flags are accepted.

`codex-sync` runtime errors are red and diagnostic warnings yellow only when stderr is a terminal and `NO_COLOR` is unset. Any value of `NO_COLOR`, including empty, disables color. Reset color immediately after each diagnostic; redirected diagnostics have no color codes. Human-facing messages use ❌ for errors, ⚠️ for warnings/prompts, ℹ️ for transfer status, and ✅ for installation/removal success. Installer and uninstaller messages are uncolored; the purge confirmation uses a plain prompt. SSH/rsync output passes through unchanged. Help describes marker-defined root resolution and the assistance flows.

## Local project resolution

Starting at physical cwd, search each physical parent through filesystem root for the nearest `.codexignore` entry, including dangling symlinks. Never search remote paths. Its containing directory defines the synchronization root for both directions, regardless of Git metadata; transfer that entire directory even from a nested invocation. Only the nearest marker is used, with no parent-rule merging or explicit ignore-path override. An invalid nearest entry fails rather than falling back. The marker must resolve to a readable regular file; symlinks to readable regular files and empty files are valid. Missing-marker assistance is specified below.

The root must already exist locally and cannot be filesystem root or physical HOME. Validate its basename, rather than the invocation subdirectory, as the remote project name. Accept ASCII letters, digits, underscores, hyphens, and internal dots; reject empty names, leading/trailing dots, path separators, whitespace, and shell syntax. Remote naming is flat, without nested workspace paths.

Reject project-name and path arguments before SSH or rsync. There is no child-directory lookup or global folder discovery. Do not require `.git` or create local directories.

## Configuration

Runtime configuration is read from `${XDG_CONFIG_HOME:-$HOME/.config}/codex-sync/`.

The uninstaller uses the same configuration directory for purge. Only the runtime configuration files below are used. A `project-folders` entry is neither read nor validated.

### `target-host`

An optional readable regular file (a symlink to one is accepted) containing an SSH host name or alias, optionally prefixed by `user@`. If missing, use `codex`. The exact accepted form is `^([a-zA-Z0-9_][a-zA-Z0-9_.-]*@)?[a-zA-Z0-9_][a-zA-Z0-9_.-]*$`. Trailing newlines are removed when reading the file; other whitespace, ports, IPv6 literals, and shell syntax are rejected. Existing non-files, unreadable files, and dangling symlinks fail. This is a host selector, not an arbitrary SSH command.

### `ignore`

An optional readable regular file of rsync-compatible exclude patterns. Symlinks to readable regular files are accepted; other existing entries fail unless the source is disabled. See Exclusions.

## Remote project resolution and validation

The remote project path is always `~/<project-name>` on the configured target host. The remote root is not independently configurable.

Before any SSH or rsync operation, complete local root, marker, ignore-file, and host validation. Before either transfer, verify the remote directory via SSH. Reject non-directory entries, dangling symlinks, and directories resolving to remote filesystem root or physical HOME.

Symlinks to directories are accepted if their physical destinations pass these checks; their targets need not be inside remote HOME. Missing directories stop the transfer except for the explicit remote push assistance below. Both `ssh` and `rsync` must be available locally before the SSH check. Transfer operands have trailing slashes and follow `--`; the remote operand is `<host>:~/<project-name>/`. SSH commands quote remote HOME paths.

## Assisted missing remote destination creation

Only a real push may offer creation when SSH confirms that `~/<project-name>` has no entry (including no dangling symlink). The check returns status 3 for absence; other failures, including SSH transport failure, stop without prompting. Existing files, dangling symlinks, and unsafe directory aliases are errors.

Require both stdin and stderr to be terminals. Prompt explicitly with the host and destination and default No `[y/N]`; accept only `y`, `Y`, `yes`, `YES`, or `Yes`. Empty input, EOF and all other responses decline. Decline and noninteractive contexts stop nonzero without mkdir or rsync. On affirmation, use SSH to run a quoted `mkdir -- "$HOME/<project-name>"` without `-p`; creation failure (including a newly appeared entry) stops. Revalidate the directory through SSH after successful creation; only a successful check allows the normal push to proceed. No local directory is created.

Pull never offers creation. Dry-run reports a missing remote destination and stops nonzero without prompting or mutating remote state, even on affirmative terminal input. Missing-local-marker assistance is a separate flow.

## Exclusions

Combine these sources in both directions, in this order (the directive below can disable only the global source):

1. Exactly three non-overridable built-in exclusion patterns: `.git/`, `.ssh/`, and `.codexignore`. No other sensitive files or generated directories are excluded automatically.
2. Optional global `${XDG_CONFIG_HOME:-$HOME/.config}/codex-sync/ignore`.
3. Required nearest local `.codexignore`, found from the physical invocation directory upward; its directory defines the local project.

Use the local marker selected by Local project resolution, including for pulls. The optional global file cannot replace it. Patterns retain rsync semantics relative to the synchronization root, apart from the metadata directive below. Never use `--delete-excluded`; excluded destination files remain protected under ordinary rsync deletion semantics.

Credentials, private keys, environment files, and other secrets outside the built-in patterns are not automatically excluded. Users must review their files, configure exclusions, and preview with `cpush --dry-run`. Exclusions and dry runs do not guarantee that secrets cannot be transferred.

Before SSH or rsync, reject lines exactly equal to `!` or `!` followed by a carriage return in either active ignore file, including an unterminated final line. Other whitespace is not stripped for this validation.

The selected local `.codexignore` may contain the metadata directive `# codex-sync: no-global-ignore`. For recognition, remove one terminal carriage return (supporting CRLF as well as LF), then trim only leading and trailing ASCII spaces and tabs. The remaining line must match that literal exactly, case-sensitively, with no additional text or changes to internal whitespace. A final line without a newline is supported. Repeated matching directives are idempotent. Other lines retain ordinary rsync semantics.

If any line matches, pass the filtered project patterns to rsync on stdin using `--exclude-from=-` and skip the global ignore file entirely, including existence/readability and list-clearing validation, for both push and pull. Remove matching metadata lines from the project patterns supplied to rsync; keep every other project rule active, including rejection of the list-clearing `!` rule. Built-in exclusions remain mandatory. Directives in the global file or an unselected ancestor marker have no special meaning.

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

For display only, replace HOME itself with `~` and its strict descendants with `~/...`; do not abbreviate paths that merely share a HOME prefix. Actual paths and synchronization behavior remain unchanged.

Show configured rules once under each origin in built-in/global/local order, sorting alphabetically within each origin (deterministic C-locale byte order), preserving duplicates. Sorting affects display only; transfer patterns retain their file order. Omit empty lines, lines containing only a carriage return, comments beginning with `#` or `;`, and matching local metadata directives; display other rule text literally, without trimming. Validation errors go to stderr with nonzero exit status. This lists configured exclusion rules without evaluating file matches; use a sync dry run for transfer previews.

## Deletion and preview

Default synchronization uses `rsync -av --delete` to mirror the selected source into the destination. Destination-only files **may be permanently deleted**.

- Display exactly `⚠️ Sync will delete destination-only files.` only for real sync operations with deletion enabled, without requiring interactive confirmation. Suppress the warning for `--dry-run` and `--no-delete`.
- `--no-delete` disables destination-only deletion.
- `--dry-run` performs a non-mutating rsync preview, including planned deletions when applicable.
- Ordinary file output comes from `rsync -av` without extra verbosity or shell tracing. Before rsync, print `ℹ️ <push|pull>: <source> -> <destination>` to stdout. Rsync failure propagates as a nonzero command result.

The preview does not mutate transfer data, but missing-marker assistance can still create a local marker and stop, as described above.

## Installation

`install.sh [--force]` copies `codex-sync`, `cpush`, and `cpull` to `$HOME/.local/bin`, without sudo, Fish setup, or editing shell startup files.

`install.sh --help` prints usage and exits 0; it ignores trailing arguments. Otherwise only a single optional `--force` is accepted; invalid arguments exit 2.

Preflight **all three** target paths before making changes:

- If absent, install.
- Use `cmp -s` for existing regular files; identical executables are not rewritten. Identical files lacking executable permission receive mode 755 without rewriting their contents.
- A differing regular file is a managed script only when its first two lines are exactly `#!/usr/bin/env bash` and `# codex-sync`. All three installable scripts carry this marker immediately after the shebang. This marker is an identification convention, not proof of authenticity.
- List managed updates and unrelated collisions separately. Ask once per nonempty group: update managed scripts, then explicitly replace unrelated files or symlinks, each defaulting to No `[y/N]`. Accept only `y`, `Y`, `yes`, `YES`, or `Yes`; EOF and other answers decline.
- Require terminal stdin and stderr for confirmations; otherwise fail without changes unless `--force` explicitly overrides both confirmations.
- Symlinks (including dangling links and links to directories) are always collisions, never managed or identical; replacement replaces the link, not its referent. Other non-regular entries and directories fail even with `--force`.
- Complete all preflight checks and confirmations before modifying any target. Stage all changed commands with mode 755 before moving them into place; unchanged executables retain their permissions and identity. The final three-file replacement is not atomic as a group.
- Never manage user configuration files.

Installation is by copy, not symlink. It does not edit `PATH`.

## Uninstall

`uninstall.sh [--purge]` checks `$HOME/.local/bin/{codex-sync,cpush,cpull}`. It accepts either no arguments or the single option `--purge`; all other argument combinations (including `--help`) print usage to stderr and exit 2.

Missing entries are skipped. A regular, non-symlink file is removed if its first two lines match the same managed header used by installation. Contents are not compared with the source files: modified scripts retaining the header are removed without confirmation. Symlinks, non-regular entries, and files without that header are preserved with a warning and result in status 1. Successful removals are reported individually. Removal failures stop the script under `set -e`; earlier removals are not rolled back. Without `--purge`, configuration is preserved. Project `.codexignore` files are never targeted.

With `--purge`, command removal happens first, followed by optional recursive removal of exactly `${XDG_CONFIG_HOME:-$HOME/.config}/codex-sync`, matching runtime configuration resolution. Unset or empty `XDG_CONFIG_HOME` falls back to `$HOME/.config`; relative values remain relative to the invocation directory. Purge applies only if this entry is a directory and is not itself a symlink; absent entries, files, and symlinks are silently skipped. Parent components are not checked for symlinks.

For an eligible configuration directory, only stdin must be a terminal. The Bash `read -r -p` prompt is `Remove configuration <path>? [y/N] `. Unlike the other confirmations, the read uses default IFS whitespace handling, and only `y`, `Y`, and lowercase `yes` affirm. Affirmation runs `rm -r -- <path>` without a further prompt and reports success. A negative or unrecognized answer preserves configuration without adding an error status; EOF exits 1. Nonterminal stdin preserves configuration with a warning and sets status 1. Purge can proceed even if unrelated command entries were preserved; that earlier status remains 1.

## Existing tests and coverage gaps

Self-contained Bash tests use isolated temporary HOME/config/project directories and mocked SSH/rsync. Remote-command tests execute the generated SSH expressions against a temporary remote HOME. No live host or user installation is required. The existing test assertions are grouped below; this inventory does not imply every assertion agrees with current code:

- `test-project-lookup.sh`, `test-root-resolution.sh`, `test-ignore-lookup.sh`: marker-defined physical roots, nested/symlinked invocation, nearest-wins selection, flat remote names, invalid nearest entries, root/name safety, positional-argument rejection, and unused `project-folders` entries.
- `test-invalid-input.sh`, `test-local-remote-validation.sh`: invalid names/options/hosts and validation failures preventing transfers in both directions.
- `test-exclusions.sh`, `test-ignore-directive.sh`: XDG host/ignore configuration, required readable local markers, empty/optional sources, cumulative mandatory exclusions, list-clearing rejection, exact directive recognition (spaces/tabs, CRLF, repeated and unterminated lines), disabled global validation, retained local rules, and ineffective near matches/global/ancestor directives.
- `test-ignore-creation.sh`: default/negative/affirmative responses, noninteractive refusal, optional Git hint and fallback, exclusive file/symlink race protection, dry-run stop behavior, read-only inspect, and no SSH/rsync after assistance.
- `test-inspect-command.sh`, `test-color.sh`: exact report layout, grouping/sorting/duplicates/literal rules, empty/absent/disabled sources, strict HOME abbreviation, shared validation, local-only execution, argument rejection, informational options, emoji diagnostics, terminal styling, redirection, `NO_COLOR` (including empty), and unchanged external output.
- `test-remote-creation.sh`: real remote-check expressions, existing/missing/invalid entries and unsafe aliases, shell-safe HOME quoting, all accepted responses and default/negative/EOF refusal, noninteractive/dry-run/pull refusal, SSH/mkdir/revalidation failures, and transfer only after successful validation.
- `test-transfer.sh`: direction, trailing slashes, default host and deletion, dry-run, no-delete and combined options, with warnings only for real deleting transfers.
- `test-installation.sh`: copies/header markers, version, unchanged-file identity and permission restoration, managed/header-near-match/unrelated collisions, symlink referent preservation, directory refusal, all confirmations before changes, noninteractive/force handling, staging failure cleanup, and uninstall/config preservation assertions. Its uninstall assertion is stale: it expects an appended modification to preserve a managed command and produce failure, whereas current uninstall removes it and succeeds. This aborts the test before its later installer cases can run.

Interactive and terminal-color cases require util-linux `script` and are skipped if unavailable. Unreadable-file checks are skipped when the executing user can still read mode-000 files.

`test-uninstall-purge.sh` covers unset, empty, custom (including spaces), and relative XDG configuration paths, affirmative/default/negative confirmation, noninteractive refusal, preservation of the unselected directory, and configuration symlink protection. Interactive cases require util-linux `script`. The stale uninstall assertion is a test/code discrepancy, not the uninstall contract.

`tests/run.sh` runs every `test-*.sh` in filename order and stops at the first failure. `test-installation.sh` invokes installation and removal only inside its temporary HOME. Syntax, formatting and lint checks can inspect scripts without executing them; individual behavior tests can be run separately when installation/removal execution is out of scope.
