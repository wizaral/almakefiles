ifeq ($(ALMAKE_DISABLE_MODULE_ENV),1)
else ifndef __ALMAKE_INCLUDE_GUARD_ENV
override __ALMAKE_INCLUDE_GUARD_ENV = 1
ALMAKE_DISABLE_MODULE_ENV ?=

###

ALMAKE_NO_AUTO_ENV_INIT ?=
ALMAKE_ENV_EXAMPLE_PROVENANCE_WARN_ONLY_CSV ?=
ALMAKE_ENV_TARGET_FILE_VARIABLES ?=
ALMAKE_ENV_TARGET_FILES_CSV_VARIABLES ?= ALMAKE_ENV_COMPOSE_FILES_CSV

override __ALMAKE_ENV_FILE_NAMES := $(sort $(ALMAKE_ENV_FILE) $(__ALMAKE_DEFAULT_ENV_FILE))

override __ALMAKE_DECLARED_ENV_FILES := $(foreach variable,$(strip $(ALMAKE_ENV_TARGET_FILE_VARIABLES)),$(strip $($(variable))))
override __ALMAKE_DECLARED_ENV_FILES += $(foreach variable,$(strip $(ALMAKE_ENV_TARGET_FILES_CSV_VARIABLES)),$(call almake-split-comma,$($(variable)),,))

override __ALMAKE_DECLARED_ENV_FILES := $(filter-out $(__ALMAKE_ENV_FILE_NAMES),$(__ALMAKE_DECLARED_ENV_FILES))
override __ALMAKE_EXISTING_ENV_FILES := $(filter-out $(wildcard .env*.example) $(__ALMAKE_ENV_FILE_NAMES),$(wildcard .env*))

override __ALMAKE_MISSING_ENV_FILES := $(filter-out $(__ALMAKE_EXISTING_ENV_FILES),$(__ALMAKE_DECLARED_ENV_FILES))
override __ALMAKE_ALL_ENV_FILES := $(sort $(__ALMAKE_DECLARED_ENV_FILES) $(__ALMAKE_EXISTING_ENV_FILES))

###

override __ALMAKE_AUTO_ENV_INIT_ENABLED := $(if $(or $(__ALMAKE_QUERY_MODE),$(filter 1,$(ALMAKE_NO_AUTO_ENV_INIT)),$(if $(__ALMAKE_ENV_MAKE_AVAILABLE),,1),$(if $(__ALMAKE_TOP_LEVEL),,1)),,1)
override __ALMAKE_ENV_MAKE_SCRIPT_ARGS := ALMAKE_DIRECTORY_PATH ALMAKE_ENV_FILE ALMAKE_SCAN_INCLUDE_DIRS_CSV ALMAKE_SCAN_INCLUDE_GLOBS_CSV ALMAKE_SCAN_EXCLUDE_DIRS_CSV ALMAKE_SCAN_EXCLUDE_GLOBS_CSV __ALMAKE_COMMAND_LINE_VARIABLES __ALMAKE_SCAN_EXCLUDE_MAKEFILES_CSV
override __ALMAKE_ENV_INIT_SCRIPT_ARGS := ALMAKE_ENV_EXAMPLE_PROVENANCE_WARN_ONLY_CSV

override __ALMAKE_AUTO_ENV_INIT_OUTPUT := $(if $(__ALMAKE_AUTO_ENV_INIT_ENABLED),$(shell $(call almake-gen-env-list,$(__ALMAKE_ENV_INIT_SCRIPT_ARGS)) bash $(__ALMAKE_ENV_INIT_SCRIPT) $(__ALMAKE_MISSING_ENV_FILES) >&2),)

ifneq ($(__ALMAKE_AUTO_ENV_INIT_ENABLED),)
ifneq ($(.SHELLSTATUS),0)
$(error automatic env initialization failed)
endif
endif

###

env.sync-env.mk: ## Append newly discovered ?= defaults to ALMAKE_ENV_FILE
	$(call almake-gen-env-list,$(__ALMAKE_ENV_MAKE_SCRIPT_ARGS)) bash $(__ALMAKE_ENV_MAKE_SCRIPT) sync

env.reinit-env.mk: ## Rebuild ALMAKE_ENV_FILE from discovered defaults
	$(call almake-gen-env-list,$(__ALMAKE_ENV_MAKE_SCRIPT_ARGS)) bash $(__ALMAKE_ENV_MAKE_SCRIPT) reinit

var.debug: ## Show effective values and winners for discovered ?= variables
	$(call almake-gen-env-list,$(__ALMAKE_ENV_MAKE_SCRIPT_ARGS) ALMAKE_MAKE_BIN) bash $(__ALMAKE_ENV_MAKE_SCRIPT) debug

var.debug-full: ## Show effective values and winners for all project variables
	$(call almake-gen-env-list,$(__ALMAKE_ENV_MAKE_SCRIPT_ARGS) ALMAKE_MAKE_BIN) bash $(__ALMAKE_ENV_MAKE_SCRIPT) debug --full

# 1 - reinit target suffix, 2 - env file path
override define almake-target-reinit-env
env.reinit-$(1:.%=%): ## Reinitialize the matching $1 file from $1.example
	$(call almake-gen-env-list,$(__ALMAKE_ENV_INIT_SCRIPT_ARGS)) bash $(__ALMAKE_ENV_INIT_SCRIPT) --force $1
endef

$(foreach file,$(__ALMAKE_ALL_ENV_FILES),$(eval $(call almake-target-reinit-env,$(file))))

endif
