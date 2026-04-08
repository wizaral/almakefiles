# Git Module

## Public Variables

- `ALMKFS_GIT_CLEAN_EXCLUDES_CSV`
  - CSV list of paths excluded from `git clean`
- `ALMKFS_GIT_CLEAN_FLAGS`
  - flags passed to `git clean`

## Public Targets

### Static

- `git.clean`
- `git.dry-clean`

## Behavior

- Defaults `ALMKFS_GIT_CLEAN_EXCLUDES_CSV` to `$(ALMKFS_ENV_FILE)`.
- Uses `git clean -fdx` for destructive cleanup and `git clean -fdxn` for preview mode.
- Preserves excluded local files across cleanup runs.
