ifeq ($(ALMAKE_DISABLE_MODULE_DOCKER_COMPOSE),1)
else ifndef __ALMAKE_INCLUDE_GUARD_DOCKER_COMPOSE
override __ALMAKE_INCLUDE_GUARD_DOCKER_COMPOSE = 1
ALMAKE_DISABLE_MODULE_DOCKER_COMPOSE ?=

override ALMAKE_DOCKER_COMPOSE := $(if $(shell command -v docker-compose 2>/dev/null),docker-compose,docker compose)
ALMAKE_DOCKER_COMPOSE_UID ?= $(shell id -u)

ALMAKE_ENV_COMPOSE_FILES_CSV ?= .env
override __ALMAKE_ENV_COMPOSE_FILES_ARGS := $(call almake-split-comma,$(ALMAKE_ENV_COMPOSE_FILES_CSV),--env-file ,)

ALMAKE_DOCKER_COMPOSE_FILES_CSV ?= compose.yaml
override __ALMAKE_DOCKER_COMPOSE_FILES_ARGS := $(call almake-split-comma,$(ALMAKE_DOCKER_COMPOSE_FILES_CSV),-f ,)

override ALMAKE_DOCKER_COMPOSE_COMMAND := $(ALMAKE_DOCKER_COMPOSE) $(__ALMAKE_ENV_COMPOSE_FILES_ARGS) $(__ALMAKE_DOCKER_COMPOSE_FILES_ARGS)
override __ALMAKE_DOCKER_COMPOSE_SERVICES := $(sort $(strip $(shell $(ALMAKE_DOCKER_COMPOSE_COMMAND) config --services 2>/dev/null)))

###

$(eval $(call almake-target-require,docker,))
$(eval $(call almake-target-require-base,$(ALMAKE_DOCKER_COMPOSE) version >/dev/null 2>&1,docker-compose,))

compose.ensure-tools: common.ensure-docker common.ensure-docker-compose ## Ensure docker compose tool is installed

###

# 1 - service name, 2 - additional parameters
override define almake-target-exec-service
compose.exec-$1: compose.ensure-tools ## Execute a shell in the running $1 container
	$(ALMAKE_DOCKER_COMPOSE_COMMAND) exec -u $(ALMAKE_DOCKER_COMPOSE_UID) $1 sh $2
endef

$(foreach service,$(__ALMAKE_DOCKER_COMPOSE_SERVICES),$(eval $(call almake-target-exec-service,$(service),)))

###

compose.config: compose.ensure-tools ## Render compose configuration
	$(ALMAKE_DOCKER_COMPOSE_COMMAND) config

compose.build: compose.ensure-tools ## Build local images
	$(ALMAKE_DOCKER_COMPOSE_COMMAND) build

compose.pull: compose.ensure-tools ## Pull latest images
	$(ALMAKE_DOCKER_COMPOSE_COMMAND) pull

compose.up: compose.ensure-tools ## Start compose stack in detached mode
	$(ALMAKE_DOCKER_COMPOSE_COMMAND) up -d

compose.down: compose.ensure-tools ## Stop compose stack
	$(ALMAKE_DOCKER_COMPOSE_COMMAND) down --remove-orphans

compose.logs: compose.ensure-tools ## Follow compose stack logs
	$(ALMAKE_DOCKER_COMPOSE_COMMAND) logs -f

compose.ps: compose.ensure-tools ## Show compose stack status
	$(ALMAKE_DOCKER_COMPOSE_COMMAND) ps

compose.restart: compose.down compose.up ## Restart compose stack

endif
