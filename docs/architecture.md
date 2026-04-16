# Architecture

This document explains how `almakefiles` works internally.
For public guarantees and supported environments, use [`contracts.md`](contracts.md).

## Overview

A normal top-level load has three layers:

1. `include.mk` resolves and guards the drop-in entrypoint.
2. `mk/common.mk` derives shared state, discovers modules, and bootstraps `ALMKFS_ENV_FILE`.
3. Optional modules load and may register post-include hooks to materialize generated targets after env bootstrap.

## Entrypoint Resolution

The consumer project includes a literal path to `include.mk`.
`include.mk` resolves its sibling `mk/common.mk` from the actual loaded path and rejects conflicting canonical entrypoints in the same run.

Startup path resolution keeps the loaded `include.mk` and `mk/common.mk` paths in their literal relative form until canonicalization is needed.
That keeps first-load behavior stable when the consumer project root contains spaces.

## Shared State In `mk/common.mk`

`mk/common.mk` is where the cross-module baseline is established:

- canonical `ALMKFS_DIRECTORY_PATH`
- default `ALMKFS_ENV_FILE` placement
- raw `MAKEOVERRIDES` preserved for nested Make database reads
- the loaded Makefile list for help generation
- query-style classification from real Make option tokens

That query classification runs before file-writing bootstrap paths so query-style invocations do not create or rewrite local files.

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

`mk/common.mk` computes the active module set after applying `ALMKFS_DISABLE_MODULE_<MODULE_NAME> = 1`.

## `ALMKFS_ENV_FILE` Lifecycle

`mk/common.mk` owns the early `.env.mk` path:

- choose the default file path
- bootstrap the file when a normal top-level run needs it
- validate an existing file before including it
- stop the invocation on invalid content

The actual file scanning and rebuild logic lives in `scripts/env-make.sh`, but the timing of bootstrap and early include belongs to `mk/common.mk`.

## Default Scanning Pipeline

`scripts/env-make.sh` scans `?=` defaults from:

- consumer-root `makefile`, `Makefile`, `GNUmakefile`
- consumer-root `*.mk` and `*.makefile`
- `$(ALMKFS_DIRECTORY_PATH)/include.mk`
- `$(ALMKFS_DIRECTORY_PATH)/mk/*.mk`
- `$(ALMKFS_DIRECTORY_PATH)/mk/*.makefile`

The scan is make-aware rather than regex-only:

- only real top-level `?=` assignments survive into `.env.mk` and `var.debug`
- hidden Makefiles and disabled module files are excluded
- duplicate defaults are reported and skipped

## Help Pipeline

`scripts/help.sh` builds the final `help` output from two sources:

- active targets from `make -pnRr help`
- `##` declarations from the loaded Makefiles

Only targets that exist in the active Make database are rendered.
After matching is complete, the final rows are sorted once globally with `LC_ALL=C`.

## Late Generated Targets

Some targets cannot be materialized correctly until the rest of the startup flow has already run.
For that case, `mk/common.mk` exposes post-include hooks.

The Docker Compose module uses those hooks to generate concrete `compose.sh-<service>` and `compose.exec-<service>` targets after env bootstrap and module loading, so direct first-run invocation works without hard-coding service names in advance.
