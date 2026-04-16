# Common Module

This module owns shared startup state and helpers used by the rest of the drop-in.

## Public Variables

- `ALMKFS_DIRECTORY_PATH`
  - computed from the actual loaded drop-in path
- `ALMKFS_ENV_FILE`
  - configurable default for the generated Make-local config file
- `ALMKFS_MAKE_BIN`
  - computed Make binary passed into internal shell helpers
- `ALMKFS_GLOBAL_MAKEFLAGS`
  - configurable extra flags appended to `MAKEFLAGS`
- `ALMKFS_SCAN_INCLUDE_DIRS_CSV`
- `ALMKFS_SCAN_EXCLUDE_DIRS_CSV`
- `ALMKFS_SCAN_INCLUDE_GLOBS_CSV`
- `ALMKFS_SCAN_EXCLUDE_GLOBS_CSV`

## Public Targets

- `help`
- `common.ensure-<tool>`

## Behavior

- Sets the default goal to `help`.
- Detects and validates the active drop-in directory.
- Guards `include.mk` and rejects conflicting canonical entrypoints.
- Computes the default location of `ALMKFS_ENV_FILE`.
- Bootstraps and includes `ALMKFS_ENV_FILE` early on normal top-level runs.
- Classifies query-style runs from real Make option tokens instead of substring matches inside unrelated `MAKEFLAGS` arguments.
- Discovers optional module files and applies module disable switches before loading them.
- Preserves raw command-line variable winners and the loaded Makefile list for nested help and debug database reads.
- Runs post-include hooks so modules can materialize generated targets after env bootstrap.

## Notes

- `ALMKFS_ENV_FILE` is excluded from regular `.env*` handling.
- Module switch naming is documented in [`../reference.md`](../reference.md).
