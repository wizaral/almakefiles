# Common Module

## Public Variables

- `ALMAKE_DIRECTORY_PATH`
  - computed automatically from the loaded drop-in path
- `ALMAKE_ENV_FILE`
  - configurable default for the generated Make-local config file
- `ALMAKE_MAKE_BIN`
  - computed Make binary passed into internal shell helpers
- `ALMAKE_GLOBAL_MAKEFLAGS`
  - configurable extra flags appended to `MAKEFLAGS`
- `ALMAKE_SCAN_INCLUDE_DIRS_CSV`
- `ALMAKE_SCAN_EXCLUDE_DIRS_CSV`
- `ALMAKE_SCAN_INCLUDE_GLOBS_CSV`
- `ALMAKE_SCAN_EXCLUDE_GLOBS_CSV`

## Public Module Switches

- `ALMAKE_DISABLE_MODULE_<MODULE_NAME> = 1`

## Public Targets

### Static

- `help`

### Generated

- `common.ensure-<tool>`

## Behavior

- Sets the default goal to `help`.
- Detects and validates the active drop-in directory.
- Guards `include.mk` and rejects conflicting canonical entrypoints.
- Computes the default location of `ALMAKE_ENV_FILE`.
- Discovers active optional module files.
- Bootstraps and includes `ALMAKE_ENV_FILE` early on normal top-level runs.
- Passes the active Makefile list to the help generator.
- Preserves outer command-line variable winners for nested debug/help database reads.

## Notes

- `ALMAKE_ENV_FILE` is special and is excluded from normal `.env*` handling.
- Query-style runs must not create `ALMAKE_ENV_FILE`.
