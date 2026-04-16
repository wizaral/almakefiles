ifeq ($(ALMKFS_DISABLE_MODULE_ENV),1)
else ifndef __ALMKFS_INCLUDE_GUARD_ENV
override __ALMKFS_INCLUDE_GUARD_ENV = 1
ALMKFS_DISABLE_MODULE_ENV ?=

###

ALMKFS_NO_AUTO_ENV_INIT ?=
ALMKFS_ENV_EXAMPLE_PROVENANCE_WARN_ONLY_CSV ?=
ALMKFS_ENV_TARGET_FILE_VARIABLES ?=
ALMKFS_ENV_TARGET_FILES_CSV_VARIABLES ?= ALMKFS_ENV_COMPOSE_FILES_CSV

override __ALMKFS_ENV_FILE_NAMES := $(sort $(ALMKFS_ENV_FILE) $(__ALMKFS_DEFAULT_ENV_FILE))

override __ALMKFS_DECLARED_ENV_FILES := $(foreach variable,$(strip $(ALMKFS_ENV_TARGET_FILE_VARIABLES)),$(strip $($(variable))))
override __ALMKFS_DECLARED_ENV_FILES += $(foreach variable,$(strip $(ALMKFS_ENV_TARGET_FILES_CSV_VARIABLES)),$(call almkfs-split-comma,$($(variable)),,))

override __ALMKFS_DECLARED_ENV_FILES := $(filter-out $(__ALMKFS_ENV_FILE_NAMES),$(__ALMKFS_DECLARED_ENV_FILES))
override __ALMKFS_EXISTING_ENV_FILES := $(filter-out $(wildcard .env*.example) $(__ALMKFS_ENV_FILE_NAMES),$(wildcard .env*))

override __ALMKFS_MISSING_ENV_FILES := $(filter-out $(__ALMKFS_EXISTING_ENV_FILES),$(__ALMKFS_DECLARED_ENV_FILES))
override __ALMKFS_ALL_ENV_FILES := $(sort $(__ALMKFS_DECLARED_ENV_FILES) $(__ALMKFS_EXISTING_ENV_FILES))

###

override __ALMKFS_AUTO_ENV_INIT_ENABLED := $(if $(or $(__ALMKFS_QUERY_MODE),$(filter 1,$(ALMKFS_NO_AUTO_ENV_INIT)),$(filter env.fix-example-provenance,$(MAKECMDGOALS)),$(if $(__ALMKFS_ENV_MAKE_AVAILABLE),,1),$(if $(__ALMKFS_TOP_LEVEL),,1)),,1)
override __ALMKFS_ENV_MAKE_SCRIPT_ARGS := ALMKFS_DIRECTORY_PATH ALMKFS_ENV_FILE ALMKFS_SCAN_INCLUDE_DIRS_CSV ALMKFS_SCAN_INCLUDE_GLOBS_CSV ALMKFS_SCAN_EXCLUDE_DIRS_CSV ALMKFS_SCAN_EXCLUDE_GLOBS_CSV __ALMKFS_RAW_MAKEOVERRIDES __ALMKFS_SCAN_EXCLUDE_MAKEFILES_CSV
override __ALMKFS_ENV_INIT_SCRIPT_ARGS := ALMKFS_ENV_EXAMPLE_PROVENANCE_WARN_ONLY_CSV

override __ALMKFS_AUTO_ENV_INIT_OUTPUT := $(if $(__ALMKFS_AUTO_ENV_INIT_ENABLED),$(shell $(call almkfs-gen-env-list,$(__ALMKFS_ENV_INIT_SCRIPT_ARGS)) bash $(__ALMKFS_ENV_INIT_SCRIPT) $(__ALMKFS_MISSING_ENV_FILES) >&2),)

ifneq ($(__ALMKFS_AUTO_ENV_INIT_ENABLED),)
ifneq ($(.SHELLSTATUS),0)
$(error automatic env initialization failed)
endif
endif

###

env.sync-env.mk: ## Append newly discovered ?= defaults to ALMKFS_ENV_FILE
	$(call almkfs-gen-env-list,$(__ALMKFS_ENV_MAKE_SCRIPT_ARGS)) bash $(__ALMKFS_ENV_MAKE_SCRIPT) sync

env.reinit-env.mk: ## Rebuild ALMKFS_ENV_FILE from discovered defaults
	$(call almkfs-gen-env-list,$(__ALMKFS_ENV_MAKE_SCRIPT_ARGS)) bash $(__ALMKFS_ENV_MAKE_SCRIPT) reinit

env.fix-example-provenance: ## Normalize provenance headers in .env*.example files
	$(call almkfs-gen-env-list,$(__ALMKFS_ENV_INIT_SCRIPT_ARGS)) bash $(__ALMKFS_ENV_INIT_SCRIPT) --fix-examples

var.debug: ## Show effective values and winners for discovered ?= variables
	$(call almkfs-gen-env-list,$(__ALMKFS_ENV_MAKE_SCRIPT_ARGS) ALMKFS_MAKE_BIN) bash $(__ALMKFS_ENV_MAKE_SCRIPT) debug

var.debug-full: ## Show effective values and winners for all project variables
	$(call almkfs-gen-env-list,$(__ALMKFS_ENV_MAKE_SCRIPT_ARGS) ALMKFS_MAKE_BIN) bash $(__ALMKFS_ENV_MAKE_SCRIPT) debug --full

# 1 - reinit target suffix, 2 - env file path
override define almkfs-target-reinit-env
env.reinit-$(1:.%=%): ## Reinitialize the matching $1 file from $1.example
	$(call almkfs-gen-env-list,$(__ALMKFS_ENV_INIT_SCRIPT_ARGS)) bash $(__ALMKFS_ENV_INIT_SCRIPT) --force $1
endef

$(foreach file,$(__ALMKFS_ALL_ENV_FILES),$(eval $(call almkfs-target-reinit-env,$(file))))

endif
