# Env Module

This module owns regular `.env*` initialization, `.env.mk` rebuild and sync targets, and variable debug output.

## Public Variables

- `ALMKFS_ENV_EXAMPLE_PROVENANCE_WARN_ONLY_CSV`
  - `.env*.example` files that should warn instead of being rewritten by `env.fix-example-provenance`
- `ALMKFS_ENV_TARGET_FILE_VARIABLES`
  - whitespace-separated variable names whose values are single env target paths
- `ALMKFS_ENV_TARGET_FILES_CSV_VARIABLES`
  - whitespace-separated variable names whose values are CSV env target lists
- `ALMKFS_NO_AUTO_ENV_INIT`
  - disables the late regular `.env*` auto-init step when set to `1`

## Public Targets

- `env.sync-env.mk`
- `env.reinit-env.mk`
- `env.fix-example-provenance`
- `env.reinit-<file>`
- `var.debug`
- `var.debug-full`

## Behavior

- Resolves the managed regular `.env*` target set from the configured registries.
- Excludes `ALMKFS_ENV_FILE` and its default location from regular env-file discovery.
- Auto-initializes missing regular `.env*` files from matching `.env*.example` files on normal top-level runs.
- Fails when a declared env target has no matching `.env*.example` file.
- Warns on missing or invalid provenance headers in source `.env*.example` files during normal top-level runs without rewriting the tracked examples.
- Repairs source `.env*.example` provenance only through the explicit `env.fix-example-provenance` maintenance target.
- Rebuilds or syncs `ALMKFS_ENV_FILE` from discovered non-duplicate top-level `?=` defaults.
- Writes `env.sync-env.mk` updates atomically and normalizes the missing trailing newline case before appending new defaults.
- Ignores `?=` text that appears inside recipes, heredocs, or `define` blocks.
- Prints Make-database-based winner reports through `var.debug` and `var.debug-full`.

## Notes

- `env.reinit-env.mk` rebuilds the Make-local config file.
- `env.reinit-<file>` targets operate on regular project env files, not on `ALMKFS_ENV_FILE`.
- The syntax contract for `ALMKFS_ENV_FILE` itself is defined in [`../contracts.md`](../contracts.md).
