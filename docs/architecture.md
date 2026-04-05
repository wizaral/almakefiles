# Architecture

## Entrypoint

The consumer project always includes a literal path to `include.mk`.
No public variable participates in the very first include.

That rule prevents a split-brain configuration where the user-provided variable and the actually loaded path diverge.

`include.mk` guards itself as well:

- the same canonical path may be loaded more than once
- a different canonical `include.mk` path in the same run is an immediate error

## Canonical Directory Path

`mk/common.mk` computes `ALMAKE_DIRECTORY_PATH` from the actual loaded `mk/common.mk` file.

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

`ALMAKE_ENV_FILE` is the public override for the generated Make-local config file.

Default placement:

- inside-project drop-in: `$(ALMAKE_DIRECTORY_PATH)/.env.mk`
- outside-project drop-in: `.env.mk` in the consumer project root

This keeps shared external drop-ins from also becoming shared local state.

## `.env.mk` Contract

`ALMAKE_ENV_FILE` is a validated Make-local config file.

Allowed lines:

- blank lines
- `# ...` comments
- `NAME = value`
- `NAME := value`
- `NAME ::= value`
- `NAME += value`

Allowed variable names:

- public `ALMAKE_*`
- consumer project variables

Forbidden content:

- GNU Make system variables
- `__ALMAKE_*`
- `?=` and `!=`
- directives such as `override`, `export`, `private`, `undefine`
- blocks and conditionals such as `define`, `endef`, `ifeq`, `ifneq`, `ifdef`, `ifndef`, `else`, `endif`
- include directives
- rules and targets

Invalid `.env.mk` content fails the invocation before the file is included.

## Startup Flow

Normal top-level runs follow two phases:

1. `mk/common.mk` ensures `ALMAKE_ENV_FILE` exists, validates it when present, and includes it early.
2. `mk/env.mk` optionally initializes regular `.env*` files from matching `.env*.example` files.

Declared env targets require matching `.env*.example` files.

Recursive and query-style runs must not create files.

## Module Discovery

Optional modules are discovered automatically from:

- `$(ALMAKE_DIRECTORY_PATH)/mk/*.mk`
- `$(ALMAKE_DIRECTORY_PATH)/mk/*.makefile`

Ignored files:

- `mk/.mk`
- `mk/.makefile`
- `mk/.*.mk`
- `mk/.*.makefile`
- `mk/common.mk`

Module disabling uses `ALMAKE_DISABLE_MODULE_<MODULE_NAME> = 1`.

## `.env.mk` Default Scanning

`scripts/env-make.sh` scans `?=` defaults from:

- consumer root `makefile`
- consumer root `Makefile`
- consumer root `GNUmakefile`
- consumer root `*.mk`
- consumer root `*.makefile`
- `$(ALMAKE_DIRECTORY_PATH)/include.mk`
- `$(ALMAKE_DIRECTORY_PATH)/mk/*.mk`
- `$(ALMAKE_DIRECTORY_PATH)/mk/*.makefile`

It excludes:

- hidden Makefiles
- disabled module files
- the public `ALMAKE_ENV_FILE` assignment itself
- GNU Make system variables
- `__ALMAKE_*`

Duplicate `?=` defaults are reported and skipped.

## Help Generation

`scripts/help.sh` builds `help` from two sources:

- active targets from `make -pnRr help`
- `##` declarations in the loaded Makefiles

Targets appear only when both are true:

- the declaration exists
- the target is active in the current Make database

This keeps `help` aligned with module disabling and generated target families.

## Naming Policy

- Public project-owned Make variables use `ALMAKE_`.
- Private project-owned Make variables use `__ALMAKE_`.
- `ALMAKE_* ?=` declares a supported configurable default.
- `override ALMAKE_*` declares a computed public value.
- `override __ALMAKE_*` declares private internal state.
- `ALMAKE_DISABLE_MODULE_<MODULE_NAME>` is public and disables a module only on exact `1`.
- Consumer project variables are not renamed or wrapped by almakefiles.
