# Docker Compose Module

## Public Variables

- `ALMAKE_DOCKER_COMPOSE`
  - computed compose command, for example `docker compose` or `docker-compose`
- `ALMAKE_DOCKER_COMPOSE_COMMAND`
  - computed compose command with all configured `--env-file` and `-f` arguments
- `ALMAKE_DOCKER_COMPOSE_UID`
  - UID used by `compose.exec-<service>`
- `ALMAKE_ENV_COMPOSE_FILES_CSV`
  - CSV list of env files passed as `--env-file`
- `ALMAKE_DOCKER_COMPOSE_FILES_CSV`
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

- `compose.exec-<service>`

## Behavior

- Detects compose services from the current compose configuration.
- Generates `compose.exec-<service>` targets only for discovered active services.
- Keeps generated exec targets in sync with `help`.
- Uses the configured env-file and compose-file lists for every compose command.
