# almakefiles

`almakefiles` is a drop-in GNU Make layer for development workflows.
It auto-discovers module files, bootstraps a local `.env.mk`, initializes regular `.env*` files from examples, and keeps `help` aligned with the active target set.

## Quick Start

1. Put the drop-in directory anywhere relative to the consumer project root.
2. Add one literal include line to the consumer Make entrypoint, for example `GNUmakefile`, `makefile`, or `Makefile`.
3. Run `make help`, or use `make -f path/to/entrypoint help` if the project uses a non-default Make entrypoint filename.

```make
include almakefiles/include.mk
```

Nested inside the project:

```make
include tools/dev-layer/include.mk
```

Outside the project:

```make
include ../shared/dev-layer/include.mk
```

## Path Contract

- The first include is always a literal path to `include.mk`.
- After load, `ALMAKE_DIRECTORY_PATH` is computed automatically from the actual loaded path.
- Re-including the same canonical `include.mk` path is harmless.
- Loading a different canonical `include.mk` path in the same run is a hard error.
- The published value is canonical:
  - project-root-relative when the drop-in lives inside the consumer project
  - absolute when the drop-in lives outside the consumer project
- The final directory name is irrelevant. Only the loaded path matters.

## Local Config Contract

- `ALMAKE_ENV_FILE` is the public override for the generated Make-local config file.
- `.env.mk` is a validated Make-local config file, not a generic Make fragment.
- Default placement depends on the drop-in location:
  - inside the project: `$(ALMAKE_DIRECTORY_PATH)/.env.mk`
  - outside the project: `.env.mk` in the consumer project root
- `ALMAKE_ENV_FILE` is excluded from normal `.env*` discovery and from `?=` autogeneration feedback loops.
- Allowed `.env.mk` lines:
  - blank lines
  - `# ...` comments
  - `NAME = value`
  - `NAME := value`
  - `NAME ::= value`
  - `NAME += value`
- Allowed `.env.mk` variable names:
  - public `ALMAKE_*`
  - consumer project variables
- Forbidden `.env.mk` content:
  - GNU Make system variables
  - `__ALMAKE_*`
  - any other directives, conditionals, includes, rules, or targets

## Public Surface

Configurable defaults:

- `ALMAKE_ENV_FILE`
- `ALMAKE_GLOBAL_MAKEFLAGS`
- `ALMAKE_NO_AUTO_ENV_INIT`
- `ALMAKE_SCAN_INCLUDE_DIRS_CSV`
- `ALMAKE_SCAN_EXCLUDE_DIRS_CSV`
- `ALMAKE_SCAN_INCLUDE_GLOBS_CSV`
- `ALMAKE_SCAN_EXCLUDE_GLOBS_CSV`
- `ALMAKE_DISABLE_MODULE_<MODULE_NAME>`

Computed public values:

- `ALMAKE_DIRECTORY_PATH`
- `ALMAKE_MAKE_BIN`

Module switches:

- `ALMAKE_DISABLE_MODULE_<MODULE_NAME> = 1`

Public targets:

- `help`
- `env.sync-env.mk`
- `env.reinit-env.mk`
- `env.reinit-<file>`
- `var.debug`
- `var.debug-full`
- `compose.*`
- `git.*`

## Main Behaviors

- `help` shows only targets from active modules and active generated target families.
- `.env.mk` is generated from discovered non-duplicate `?=` defaults found in:
  - root `makefile` / `Makefile` / `GNUmakefile` / `*.mk` / `*.makefile`
  - `$(ALMAKE_DIRECTORY_PATH)/include.mk`
  - `$(ALMAKE_DIRECTORY_PATH)/mk/*.mk`
  - `$(ALMAKE_DIRECTORY_PATH)/mk/*.makefile`
- `.env.mk` generation excludes `ALMAKE_ENV_FILE`, GNU Make system variables, and `__ALMAKE_*`.
- Existing `.env.mk` files are validated before they are included on every invocation.
- Hidden module files are ignored:
  - `mk/.mk`
  - `mk/.makefile`
  - `mk/.*.mk`
  - `mk/.*.makefile`
- Disabled modules are excluded from both `help` and `.env.mk` scanning.
- Normal top-level runs may initialize regular `.env*` files only from matching `.env*.example` files.
- Declared env targets require matching `.env*.example` files.
- Query-style runs such as `-n`, `-p`, `-q`, and `-pnRr` must not create or rewrite files.

## Naming Rules

- Public project-owned Make variables use the `ALMAKE_` prefix.
- Private project-owned Make variables use the `__ALMAKE_` prefix.
- `ALMAKE_* ?=` means a supported configurable default.
- `override ALMAKE_*` means a public computed value.
- `override __ALMAKE_*` means private internal state.
- Consumer project variables remain unprefixed unless the project chooses otherwise.

## Documentation Map

- [`docs/architecture.md`](docs/architecture.md)
- [`docs/modules/common.md`](docs/modules/common.md)
- [`docs/modules/env.md`](docs/modules/env.md)
- [`docs/modules/docker-compose.md`](docs/modules/docker-compose.md)
- [`docs/modules/git.md`](docs/modules/git.md)
