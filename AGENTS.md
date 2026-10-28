# Repository instructions — codex-sync

## Purpose

Maintain a small Bash utility for bidirectional project-directory synchronization over SSH and rsync, originally extracted from `wsl-scripts/scripts/sync-codex.sh`. The original source and Fish wrappers are reference material only; never modify `wsl-scripts` as part of this project.

Read `specs/001-sync-behavior.md` before implementing or changing functionality. The specification is authoritative for CLI behavior, configuration, exclusions, deletion, and installation. If a requirement is unclear or conflicts with implementation constraints, report it rather than silently inventing behavior.

Whenever behavior, CLI options, defaults, security or exclusion rules, configuration, or tests change, update the relevant files under `specs/` in the same change so the specifications always describe implemented behavior and current test coverage. Keep `README.md` consistent with the implementation and specifications in that same change.

Keep the scope narrow: no Git integration, sandbox provisioning, SSH configuration management, Python runtime, or general-purpose synchronization framework.

## Structure and conventions

Use `bin/codex-sync` as the Bash implementation, with lightweight executable `bin/cpush` and `bin/cpull` wrappers. Include `install.sh`, `uninstall.sh`, `README.md`, `LICENSE`, `specs/`, and `tests/` where useful. Do not add boilerplate without a clear purpose.

Target Debian/Linux, Bash, rsync, and OpenSSH. Use `#!/usr/bin/env bash`, `set -euo pipefail`, careful quoting, and explicit error handling. Format with shfmt, lint with ShellCheck, and check with `bash -n`. Do not depend on Fish; wrappers must work from any shell that can execute them.

Keep configuration under `${XDG_CONFIG_HOME:-$HOME/.config}/codex-sync/`. Never place real credentials or personal host information in tracked files.

## Safety and implementation

Treat rsync `--delete` as intentional default behavior **per the specification**, not an optional opt-in. Clearly warn about destination-only file deletion; implement `--dry-run` and `--no-delete`. Do not use `--delete-excluded`.

Validate local and remote project existence before any transfer. Never auto-create project directories. Validate project names, configured roots, and SSH target; avoid shell injection, unsafe path resolution, accidental root/home sync, and unsafe handling of whitespace. Do not claim that exclude patterns guarantee secret protection.

Keep the current project's user data untouched during development. Never run a real sync against a user's SSH host or projects without explicit permission.

## Testing and delivery

Write self-contained Bash tests under `tests/`, mocking SSH/rsync where possible. Cover project lookup order, no-argument behavior, invalid names, XDG config, cumulative excludes, push/pull direction, dry-run, deletion controls, and both-side validation. Do not require a real remote host or add a testing framework.

Before reporting completion, run `bash -n`, shfmt checks, ShellCheck (when available), and tests. State which checks passed or could not run.

## Documentation audiences

README.md is for end users only: what the tool does, requirements, installation, concise usage and configuration examples, `.codexignore` usage, important deletion and secrets warnings, and useful uninstall guidance. Do not include license discussion, how-to-develop guidance, agent instructions, testing commentary, architecture internals, or implementation notes.

Keep durable agent and developer instructions in AGENTS.md. Keep detailed behavioral contracts and edge cases in the authoritative `specs/` files; avoid duplicating them in README.md or AGENTS.md. Keep the user-facing facts and safety notices in README.md consistent with those contracts.

Do not initialize Git unless explicitly requested. Preserve unrelated user changes and report deviations from the specification.
