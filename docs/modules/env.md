# Env Module

## Public Variables

- `ALMKFS_ENV_EXAMPLE_PROVENANCE_WARN_ONLY_CSV`
  - `.env*.example` files that should warn instead of being auto-fixed
- `ALMKFS_ENV_TARGET_FILE_VARIABLES`
  - whitespace-separated variable names whose values are single env target paths
- `ALMKFS_ENV_TARGET_FILES_CSV_VARIABLES`
  - whitespace-separated variable names whose values are CSV env target lists
- `ALMKFS_NO_AUTO_ENV_INIT`
  - disables the late regular `.env*` auto-init step when set to `1`

## Public Targets

### Static

- `env.sync-env.mk`
- `env.reinit-env.mk`
- `var.debug`
- `var.debug-full`

### Generated

- `env.reinit-<file>`

## Behavior

- Validates `ALMKFS_ENV_FILE` before the early include path loads it.
- Resolves regular `.env*` targets from the configured registries.
- Excludes `ALMKFS_ENV_FILE` and its default location from regular env-file discovery.
- Auto-initializes missing regular `.env*` files from matching `.env*.example` files on normal top-level runs.
- Fails when a declared env target has no matching `.env*.example` file.
- Enforces provenance headers on `.env*.example` files before copying.
- Rebuilds or appends `ALMKFS_ENV_FILE` from discovered non-duplicate `?=` defaults, excluding GNU Make system variables and `__ALMKFS_*`.
- Prints variable winner reports through `var.debug` and `var.debug-full`.

## Notes

- `env.reinit-env.mk` rebuilds the Make-local config file.
- `env.reinit-<file>` targets operate on regular project env files, not on `ALMKFS_ENV_FILE`.
- `ALMKFS_ENV_FILE` accepts only blank lines, `#` comments, and assignment forms `=`, `:=`, `::=`, `+=`.
