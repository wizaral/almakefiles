# Docker Compose Module

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

### Static

- `compose.ensure-tools`
- `compose.config`
- `compose.build`
- `compose.pull`
- `compose.up`
- `compose.down`
- `compose.logs`
- `compose.ps`
- `compose.restart`

### Generated

- `compose.sh-<service>`
- `compose.exec-<service>`

## Behavior

- Generates concrete `compose.sh-<service>` targets for interactive shells in running service containers.
- Generates concrete `compose.exec-<service>` targets for arbitrary command execution through `CMD='...'`.
- Generates concrete compose service targets after module includes, so first-run direct invocation works after regular env bootstrap.
- Validates service names at runtime from `config --services` and fails with a runtime error for unknown services.
- Keeps internal pattern fallback rules for direct runtime validation when service discovery is temporarily unavailable.
- Prints generated compose service targets in `help`.
- Prefers `docker compose` as the default backend and falls back to `docker-compose` when the plugin command is unavailable.
- Uses the configured env-file and compose-file lists for every compose command.
