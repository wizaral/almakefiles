ifeq ($(ALMKFS_DISABLE_MODULE_DOCKER_COMPOSE),1)
else ifndef __ALMKFS_INCLUDE_GUARD_DOCKER_COMPOSE
override __ALMKFS_INCLUDE_GUARD_DOCKER_COMPOSE = 1
ALMKFS_DISABLE_MODULE_DOCKER_COMPOSE ?=

override ALMKFS_DOCKER_COMPOSE := $(if $(shell command -v docker-compose 2>/dev/null),docker-compose,docker compose)
ALMKFS_DOCKER_COMPOSE_UID ?= $(shell id -u)

ALMKFS_ENV_COMPOSE_FILES_CSV ?= .env
override __ALMKFS_ENV_COMPOSE_FILES_ARGS := $(call almkfs-split-comma,$(ALMKFS_ENV_COMPOSE_FILES_CSV),--env-file ,)

ALMKFS_DOCKER_COMPOSE_FILES_CSV ?= compose.yaml
override __ALMKFS_DOCKER_COMPOSE_FILES_ARGS := $(call almkfs-split-comma,$(ALMKFS_DOCKER_COMPOSE_FILES_CSV),-f ,)

override ALMKFS_DOCKER_COMPOSE_COMMAND := $(ALMKFS_DOCKER_COMPOSE) $(__ALMKFS_ENV_COMPOSE_FILES_ARGS) $(__ALMKFS_DOCKER_COMPOSE_FILES_ARGS)
override __ALMKFS_DOCKER_COMPOSE_SERVICES := $(sort $(strip $(shell $(ALMKFS_DOCKER_COMPOSE_COMMAND) config --services 2>/dev/null)))

###

$(eval $(call almkfs-target-require,docker,))
$(eval $(call almkfs-target-require-base,$(ALMKFS_DOCKER_COMPOSE) version >/dev/null 2>&1,docker-compose,))

compose.ensure-tools: common.ensure-docker common.ensure-docker-compose ## Ensure docker compose tool is installed

###

# 1 - service name, 2 - additional parameters
override define almkfs-target-exec-service
compose.exec-$1: compose.ensure-tools ## Execute a shell in the running $1 container
	$(ALMKFS_DOCKER_COMPOSE_COMMAND) exec -u $(ALMKFS_DOCKER_COMPOSE_UID) $1 sh $2
endef

$(foreach service,$(__ALMKFS_DOCKER_COMPOSE_SERVICES),$(eval $(call almkfs-target-exec-service,$(service),)))

###

compose.config: compose.ensure-tools ## Render compose configuration
	$(ALMKFS_DOCKER_COMPOSE_COMMAND) config

compose.build: compose.ensure-tools ## Build local images
	$(ALMKFS_DOCKER_COMPOSE_COMMAND) build

compose.pull: compose.ensure-tools ## Pull latest images
	$(ALMKFS_DOCKER_COMPOSE_COMMAND) pull

compose.up: compose.ensure-tools ## Start compose stack in detached mode
	$(ALMKFS_DOCKER_COMPOSE_COMMAND) up -d

compose.down: compose.ensure-tools ## Stop compose stack
	$(ALMKFS_DOCKER_COMPOSE_COMMAND) down --remove-orphans

compose.logs: compose.ensure-tools ## Follow compose stack logs
	$(ALMKFS_DOCKER_COMPOSE_COMMAND) logs -f

compose.ps: compose.ensure-tools ## Show compose stack status
	$(ALMKFS_DOCKER_COMPOSE_COMMAND) ps

compose.restart: compose.down compose.up ## Restart compose stack

endif
