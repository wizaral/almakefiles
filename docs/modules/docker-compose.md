# Docker Compose Module

This module owns compose defaults and compose-related target families.

## Public Variables

- `ALMKFS_DOCKER_COMPOSE`
  - computed compose command, for example `docker compose` or `docker-compose`
- `ALMKFS_DOCKER_COMPOSE_COMMAND`
  - computed compose command with all configured `--env-file` and `-f` arguments
- `ALMKFS_DOCKER_COMPOSE_UID`
  - UID used by generated compose shell and exec targets
- `ALMKFS_ENV_COMPOSE_FILES_CSV`
  - CSV list of env files passed as `--env-file`
- `ALMKFS_DOCKER_COMPOSE_FILES_CSV`
  - CSV list of compose files passed as `-f`

## Public Targets

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
- `compose.exec-<service>`

## Behavior

- Prefers `docker compose` as the default backend and falls back to `docker-compose` when the plugin command is unavailable.
- Uses the configured env-file and compose-file lists for every compose command.
- Generates concrete `compose.sh-<service>` and `compose.exec-<service>` targets after module includes, so direct first-run invocation works after env bootstrap.
- `compose.sh-<service>` opens `sh` in the running service container.
- `compose.exec-<service>` requires `CMD='...'` and runs that command through `sh -lc` in the running service container.
- Validates service names at runtime from `config --services` and fails for unknown services.
- Prints generated compose service targets in `help`.
