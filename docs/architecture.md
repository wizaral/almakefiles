# Architecture

## Entrypoint

The consumer project always includes a literal path to `include.mk`.
No public variable participates in the very first include.

That rule prevents a split-brain configuration where the user-provided variable and the actually loaded path diverge.

`include.mk` guards itself as well:

- the same canonical path may be loaded more than once
- a different canonical `include.mk` path in the same run is an immediate error

Startup path resolution keeps the loaded `include.mk` and `mk/common.mk` paths in their literal relative form until canonicalization is needed.
That keeps first-load behavior stable when the consumer project root contains spaces.

## Canonical Directory Path

`mk/common.mk` computes `ALMKFS_DIRECTORY_PATH` from the actual loaded `mk/common.mk` file.

The published value is canonical:

- relative to the consumer project root when the drop-in lives inside the project
- absolute when the drop-in lives outside the project

The loaded path, not the directory name, is the source of truth.

## Layout Validation

`mk/common.mk` validates that the drop-in layout contains:

- `include.mk`
- `mk/common.mk`
- `scripts/env-init.sh`
- `scripts/env-make.sh`
- `scripts/help.sh`

The module fails early if the loaded tree is incomplete.

## Local Make Config Placement

`ALMKFS_ENV_FILE` is the public override for the generated Make-local config file.

Default placement:

- inside-project drop-in: `$(ALMKFS_DIRECTORY_PATH)/.env.mk`
- outside-project drop-in: `.env.mk` in the consumer project root

This keeps shared external drop-ins from also becoming shared local state.

## `.env.mk` Contract

`ALMKFS_ENV_FILE` is a validated Make-local config file.

Allowed lines:

- blank lines
- `# ...` comments
- `NAME = value`
- `NAME := value`
- `NAME ::= value`
- `NAME += value`

Allowed variable names:

- public `ALMKFS_*`
- consumer project variables

Forbidden content:

- GNU Make system variables
- `__ALMKFS_*`
- `?=` and `!=`
- directives such as `override`, `export`, `private`, `undefine`
- blocks and conditionals such as `define`, `endef`, `ifeq`, `ifneq`, `ifdef`, `ifndef`, `else`, `endif`
- include directives
- rules and targets

Invalid `.env.mk` content fails the invocation before the file is included.

## Startup Flow

Normal top-level runs follow two phases:

1. `mk/common.mk` ensures `ALMKFS_ENV_FILE` exists, validates it when present, and includes it early.
2. `mk/env.mk` optionally initializes regular `.env*` files from matching `.env*.example` files.

Declared env targets require matching `.env*.example` files.
Normal top-level runs warn on invalid source example provenance without rewriting tracked `.env*.example` files.
Source example provenance is repaired in place only by the explicit `env.fix-example-provenance` maintenance target.

Recursive and query-style runs must not create files.
Query detection must be option-aware: non-query `MAKEFLAGS` entries such as `-Onone` or `-I dir` must not disable bootstrap just because their arguments contain `n`, `p`, or `q`.

## Module Discovery

Optional modules are discovered automatically from:

- `$(ALMKFS_DIRECTORY_PATH)/mk/*.mk`
- `$(ALMKFS_DIRECTORY_PATH)/mk/*.makefile`

Ignored files:

- `mk/.mk`
- `mk/.makefile`
- `mk/.*.mk`
- `mk/.*.makefile`
- `mk/common.mk`

Module disabling uses `ALMKFS_DISABLE_MODULE_<MODULE_NAME> = 1`.

## `.env.mk` Default Scanning

`scripts/env-make.sh` scans `?=` defaults from:

- consumer root `makefile`
- consumer root `Makefile`
- consumer root `GNUmakefile`
- consumer root `*.mk`
- consumer root `*.makefile`
- `$(ALMKFS_DIRECTORY_PATH)/include.mk`
- `$(ALMKFS_DIRECTORY_PATH)/mk/*.mk`
- `$(ALMKFS_DIRECTORY_PATH)/mk/*.makefile`

Discovery is make-aware: only real top-level `?=` assignments survive into `.env.mk` and `var.debug`; recipe bodies, heredocs, and `define` blocks do not contribute defaults.

It excludes:

- hidden Makefiles
- disabled module files
- the public `ALMKFS_ENV_FILE` assignment itself
- GNU Make system variables
- `__ALMKFS_*`

Duplicate `?=` defaults are reported and skipped.

## Help Generation

`scripts/help.sh` builds `help` from two sources:

- active targets from `make -pnRr help`
- `##` declarations in the loaded Makefiles

Targets appear only when both are true:

- the declaration exists
- the target is active in the current Make database

This keeps `help` aligned with module disabling and generated target families.
Compose service targets are generated after module includes, so `help` renders concrete `compose.sh-<service>` and `compose.exec-<service>` entries instead of only fallback pattern rules.

## Naming Policy

- Public project-owned Make variables use `ALMKFS_`.
- Private project-owned Make variables use `__ALMKFS_`.
- `ALMKFS_* ?=` declares a supported configurable default.
- `override ALMKFS_*` declares a computed public value.
- `override __ALMKFS_*` declares private internal state.
- `ALMKFS_DISABLE_MODULE_<MODULE_NAME>` is public and disables a module only on exact `1`.
- Consumer project variables are not renamed or wrapped by almakefiles.
