# AGENTS.md

## Repository Role

This repository develops the `almakefiles` drop-in layer and its self-hosted end-to-end tests.
The goal is stable mechanics, not backward compatibility.

## Core Invariants

- The consumer project uses one literal include line: `include path/to/include.mk`.
- `ALMKFS_DIRECTORY_PATH` is computed from the actual loaded `mk/common.mk` path.
- Canonical path form:
  - relative to the consumer project root when the drop-in is inside the project
  - absolute when the drop-in is outside the project
- Re-loading the same canonical `include.mk` path is allowed.
- Loading a different canonical `include.mk` path in the same run must fail immediately.
- `ALMKFS_ENV_FILE` is the only public override for the generated Make-local config file.
- Default `ALMKFS_ENV_FILE` placement:
  - inside-project drop-in: next to `include.mk`
  - outside-project drop-in: consumer project root `.env.mk`
- `.env.mk` is a validated config file, not a generic Make fragment.
- `.env.mk` may contain only blank lines, `#` comments, and assignment operators `=`, `:=`, `::=`, `+=`.
- `.env.mk` must not contain GNU Make system variables, `__ALMKFS_*`, directives, conditionals, includes, rules, or targets.
- Query-style invocations must not create or rewrite `.env.mk` or regular `.env*` files.
- `help` must list only active targets from active modules.
- Disabled modules must disappear consistently from:
  - parsed targets
  - help output
  - `.env.mk` default scanning

## Naming Rules

- Public project-owned Make variables must use the `ALMKFS_` prefix.
- Private project-owned Make variables must use the `__ALMKFS_` prefix.
- Internal Make `define` helpers must use `almkfs-...` kebab-case names.
- `ALMKFS_* ?=` is the only supported configurable-default form.
- `override ALMKFS_*` is reserved for computed public values.
- `override __ALMKFS_*` is reserved for private internal values.
- `+=` on system-owned variables must be spelled `override +=`.
- Internal helper state in shell scripts should stay local shell variables unless it must cross a process boundary.
- Module disable switches use `ALMKFS_DISABLE_MODULE_<MODULE_NAME> = 1`.

## Source Of Truth

- Canonical drop-in path detection lives in `mk/common.mk`.
- Module loading entrypoint lives in `include.mk`.
- `.env.mk` generation and variable debug output live in `scripts/env-make.sh`.
- Regular `.env*` initialization from `.env*.example` lives in `scripts/env-init.sh`.
- `help` generation lives in `scripts/help.sh`.
- Public module contracts belong in `docs/modules/*.md`.
- Cross-module architecture belongs in `docs/architecture.md`.

## File Responsibilities

### `include.mk`

- Resolves its sibling `mk/common.mk` from the actual loaded include path.
- Guards itself against duplicate loads.
- Rejects conflicting canonical entrypoints.
- Includes active optional modules after `common.mk`.

### `mk/common.mk`

- Computes canonical `ALMKFS_DIRECTORY_PATH`.
- Validates the expected drop-in layout.
- Sets the default `ALMKFS_ENV_FILE`.
- Discovers optional modules from `mk/*.mk` and `mk/*.makefile`.
- Owns early `.env.mk` bootstrap, validation, and early include.
- Owns shared Make helpers used by multiple modules.
- Preserves raw `MAKEOVERRIDES` for nested debug/help database reads.

### `mk/env.mk`

- Owns regular `.env*` initialization behavior.
- Defines env-related public targets and debug targets.
- Excludes `ALMKFS_ENV_FILE` from generic env file handling.

### `mk/docker-compose.mk`

- Owns compose-related defaults and targets.
- Generates concrete `compose.sh-<service>` and `compose.exec-<service>` targets from discovered services after module includes.
- Keeps pattern fallback rules for runtime validation when service discovery is temporarily unavailable.
- Validates compose service names at runtime.

### `mk/git.mk`

- Owns git-clean convenience targets and exclusion handling.

### `scripts/env-make.sh`

- Scans the allowed Makefile set for `?=` defaults.
- Skips duplicate defaults.
- Rejects invalid `.env.mk` content.
- Excludes GNU Make system variables and `__ALMKFS_*` from generated `.env.mk` defaults.
- Builds, syncs, and rebuilds `ALMKFS_ENV_FILE`.
- Prints debug reports from the active Make database.

### `scripts/env-init.sh`

- Warns on invalid source `.env*.example` provenance during normal top-level runs without rewriting tracked examples.
- Repairs source `.env*.example` provenance only through the explicit maintenance target.
- Initializes or reinitializes regular `.env*` targets from examples.

### `scripts/help.sh`

- Reads active targets from `make -pnRr help`.
- Reads `##` declarations from loaded Makefiles.
- Prints only targets that are actually active.

## Testing

Run after behavioral changes:

```bash
bash tests/test_make_templates.sh
```

Run shell checks after script or test changes:

```bash
shellcheck -x -P tests scripts/env-init.sh scripts/env-make.sh scripts/help.sh scripts/lib/common.sh tests/lib/test_helpers.sh tests/suites/env-init-suite.sh tests/suites/env-make-suite.sh tests/suites/system-suite.sh tests/test_make_templates.sh
```

## Documentation Rules

- Update `README.md` when the consumer-facing contract changes.
- Update `AGENTS.md` when contributor or agent workflow expectations change.
- Update `docs/architecture.md` when path resolution, startup flow, help generation, or scan rules change.
- Update the matching module document when its public vars, targets, or behaviors change.

## Commit Rules

- Commit messages must use the standard Git layout: a short `subject`, one blank line, and an optional `body`.
- Use `subject` for the concise action summary and `body` for the reason or important context when needed.
