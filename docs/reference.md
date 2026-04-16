# Reference

This page is a quick lookup for the public surface of `almakefiles`.
For behavioral guarantees, read [`contracts.md`](contracts.md).

## Common

Configurable defaults:

- `ALMKFS_ENV_FILE`
- `ALMKFS_GLOBAL_MAKEFLAGS`
- `ALMKFS_SCAN_INCLUDE_DIRS_CSV`
- `ALMKFS_SCAN_EXCLUDE_DIRS_CSV`
- `ALMKFS_SCAN_INCLUDE_GLOBS_CSV`
- `ALMKFS_SCAN_EXCLUDE_GLOBS_CSV`

Computed public values:

- `ALMKFS_DIRECTORY_PATH`
- `ALMKFS_MAKE_BIN`

Public targets:

- `help`
- `common.ensure-<tool>`

## Env

Configurable defaults:

- `ALMKFS_NO_AUTO_ENV_INIT`
- `ALMKFS_ENV_EXAMPLE_PROVENANCE_WARN_ONLY_CSV`
- `ALMKFS_ENV_TARGET_FILE_VARIABLES`
- `ALMKFS_ENV_TARGET_FILES_CSV_VARIABLES`

Public targets:

- `env.sync-env.mk`
- `env.reinit-env.mk`
- `env.fix-example-provenance`
- `env.reinit-<file>`
- `var.debug`
- `var.debug-full`

## Docker Compose

Configurable defaults:

- `ALMKFS_DOCKER_COMPOSE_UID`
- `ALMKFS_ENV_COMPOSE_FILES_CSV`
- `ALMKFS_DOCKER_COMPOSE_FILES_CSV`

Computed public values:

- `ALMKFS_DOCKER_COMPOSE`
- `ALMKFS_DOCKER_COMPOSE_COMMAND`

Public targets:

- `compose.ensure-tools`
- `compose.config`
- `compose.build`
- `compose.pull`
- `compose.up`
- `compose.down`
- `compose.logs`
- `compose.ps`
- `compose.restart`
- `compose.sh-<service>`
- `compose.exec-<service>` with `CMD='...'`

## Git

Configurable defaults:

- `ALMKFS_GIT_CLEAN_EXCLUDES_CSV`
- `ALMKFS_GIT_CLEAN_FLAGS`

Public targets:

- `git.clean`
- `git.dry-clean`

## Module Switches

- `ALMKFS_DISABLE_MODULE_<MODULE_NAME> = 1`

## Detailed Module References

- [`docs/modules/common.md`](modules/common.md)
- [`docs/modules/env.md`](modules/env.md)
- [`docs/modules/docker-compose.md`](modules/docker-compose.md)
- [`docs/modules/git.md`](modules/git.md)
