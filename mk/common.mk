ifndef __ALMAKE_INCLUDE_GUARD_COMMON
override __ALMAKE_INCLUDE_GUARD_COMMON = 1

override .DEFAULT_GOAL := help
override ALMAKE_MAKE_BIN := $(MAKE)

###

override __ALMAKE_EMPTY :=
override __ALMAKE_SPACE := $(__ALMAKE_EMPTY) $(__ALMAKE_EMPTY)
override __ALMAKE_COMMA := ,
override __ALMAKE_SQUOTE := '
override __ALMAKE_SQUOTE_ESCAPE := '"'"'

# 1 - comma separated list, 2 - item prefix, 3 - item suffix
override define almake-split-comma
$(foreach item,$(subst $(__ALMAKE_COMMA), ,$1),$2$(item)$3)
endef

# 1 - whitespace separated list
override define almake-join-comma
$(subst $(__ALMAKE_SPACE),$(__ALMAKE_COMMA),$(strip $1))
endef

# 1 - raw value
override define almake-shell-quote
'$(subst $(__ALMAKE_SQUOTE),$(__ALMAKE_SQUOTE_ESCAPE),$1)'
endef

# 1 - variable name
override define almake-pass-env
$(patsubst %,%=$(call almake-shell-quote,$($1)),$1)
endef

# 1 - comma separated list of variable names
override define almake-gen-env-list
$(foreach v,$(call almake-split-comma,$1,,),$(call almake-pass-env,$v))
endef

# 1 - whitespace separated list of needles, 2 - haystack
override define almake-findstring-any
$(strip $(foreach needle,$1,$(findstring $(needle),$2)))
endef

# 1 - raw value
override define almake-upper-snake
$(shell printf '%s\n' $(call almake-shell-quote,$1) | tr '[:lower:]-' '[:upper:]_')
endef

# 1 - module file path
override define almake-module-name
$(basename $(notdir $1))
endef

# 1 - module file path
override define almake-module-disable-var
ALMAKE_DISABLE_MODULE_$(call almake-upper-snake,$(call almake-module-name,$1))
endef

# 1 - whitespace separated list of module file paths
override define almake-active-module-files
$(strip $(foreach module,$1,$(if $(filter 1,$($(call almake-module-disable-var,$(module)))),,$(module))))
endef

# 1 - whitespace separated list of module file paths
override define almake-disabled-module-files
$(strip $(foreach module,$1,$(if $(filter 1,$($(call almake-module-disable-var,$(module)))),$(module),)))
endef

# 1 - command to check, 2 - tool name, 3 - message
override define almake-require-base
$1 || (echo "$2 is required$3" && exit 1)
endef

# 1 - command to check, 2 - tool name, 3 - message
override define almake-target-require-base
common.ensure-$2: ## Ensures $2 is installed
	$(call almake-require-base,$1,$2,$3)
endef

# 1 - tool name, 2 - message
override define almake-require
$(call almake-require-base,command -v $1 >/dev/null 2>&1,$1,$2)
endef

# 1 - tool name, 2 - message
override define almake-target-require
common.ensure-$1: ## Ensures $1 is installed
	$(call almake-require,$1,$2)
endef

###

override __ALMAKE_COMMON_MAKEFILE := $(realpath $(lastword $(MAKEFILE_LIST)))
override __ALMAKE_MK_DIRECTORY := $(patsubst %/,%,$(dir $(__ALMAKE_COMMON_MAKEFILE)))
override __ALMAKE_DIRECTORY_REALPATH := $(patsubst %/,%,$(dir $(__ALMAKE_MK_DIRECTORY)))
override __ALMAKE_PROJECT_ROOT_REALPATH := $(realpath $(CURDIR))

override ALMAKE_DIRECTORY_PATH := $(shell realpath --relative-base=$(call almake-shell-quote,$(__ALMAKE_PROJECT_ROOT_REALPATH)) --relative-to=$(call almake-shell-quote,$(__ALMAKE_PROJECT_ROOT_REALPATH)) $(call almake-shell-quote,$(__ALMAKE_DIRECTORY_REALPATH)))

override __ALMAKE_DIRECTORY_INSIDE_PROJECT := $(if $(filter /%,$(ALMAKE_DIRECTORY_PATH)),,1)
override __ALMAKE_EXPECTED_INCLUDE_MAKEFILE := $(ALMAKE_DIRECTORY_PATH)/include.mk
override __ALMAKE_EXPECTED_COMMON_MAKEFILE := $(ALMAKE_DIRECTORY_PATH)/mk/common.mk
override __ALMAKE_ENV_INIT_SCRIPT := $(ALMAKE_DIRECTORY_PATH)/scripts/env-init.sh
override __ALMAKE_ENV_MAKE_SCRIPT := $(ALMAKE_DIRECTORY_PATH)/scripts/env-make.sh
override __ALMAKE_HELP_SCRIPT := $(ALMAKE_DIRECTORY_PATH)/scripts/help.sh
override __ALMAKE_DEFAULT_ENV_FILE := $(if $(__ALMAKE_DIRECTORY_INSIDE_PROJECT),$(if $(filter .,$(ALMAKE_DIRECTORY_PATH)),.env.mk,$(ALMAKE_DIRECTORY_PATH)/.env.mk),.env.mk)

ALMAKE_ENV_FILE ?= $(__ALMAKE_DEFAULT_ENV_FILE)

$(if $(wildcard $(__ALMAKE_EXPECTED_INCLUDE_MAKEFILE)),,$(error Invalid almakefiles layout: missing $(__ALMAKE_EXPECTED_INCLUDE_MAKEFILE)))
$(if $(wildcard $(__ALMAKE_EXPECTED_COMMON_MAKEFILE)),,$(error Invalid almakefiles layout: missing $(__ALMAKE_EXPECTED_COMMON_MAKEFILE)))
$(if $(filter $(__ALMAKE_COMMON_MAKEFILE),$(realpath $(__ALMAKE_EXPECTED_COMMON_MAKEFILE))),,$(error Invalid almakefiles layout: loaded $(__ALMAKE_COMMON_MAKEFILE) but expected $(__ALMAKE_EXPECTED_COMMON_MAKEFILE)))
$(if $(wildcard $(__ALMAKE_ENV_INIT_SCRIPT)),,$(error Invalid almakefiles layout: missing $(__ALMAKE_ENV_INIT_SCRIPT)))
$(if $(wildcard $(__ALMAKE_ENV_MAKE_SCRIPT)),,$(error Invalid almakefiles layout: missing $(__ALMAKE_ENV_MAKE_SCRIPT)))
$(if $(wildcard $(__ALMAKE_HELP_SCRIPT)),,$(error Invalid almakefiles layout: missing $(__ALMAKE_HELP_SCRIPT)))

###

override __ALMAKE_TOP_LEVEL := $(if $(filter 0,$(MAKELEVEL)),1,)
override __ALMAKE_QUERY_FLAGS := $(filter-out --% %=%,$(strip $(MAKEFLAGS)))
override __ALMAKE_QUERY_MODE := $(if $(or $(filter --just-print --dry-run --recon --print-data-base --question,$(strip $(MAKEFLAGS))),$(call almake-findstring-any,n p q,$(__ALMAKE_QUERY_FLAGS))),1,)
override __ALMAKE_ENV_MAKE_RULE_ENABLED := $(if $(or $(__ALMAKE_QUERY_MODE),$(if $(__ALMAKE_TOP_LEVEL),,1)),,1)
override __ALMAKE_COMMAND_LINE_VARIABLES := $(strip $(foreach v,$(.VARIABLES),$(if $(filter command line,$(origin $(v))),$(v),)))

override __ALMAKE_MK_CONTENT := $(wildcard $(ALMAKE_DIRECTORY_PATH)/mk/*.mk) $(wildcard $(ALMAKE_DIRECTORY_PATH)/mk/*.makefile)
override __ALMAKE_HIDDEN_MODULE_FILES := $(strip $(ALMAKE_DIRECTORY_PATH)/mk/.mk $(ALMAKE_DIRECTORY_PATH)/mk/.makefile $(wildcard $(ALMAKE_DIRECTORY_PATH)/mk/.*.mk) $(wildcard $(ALMAKE_DIRECTORY_PATH)/mk/.*.makefile))
override __ALMAKE_MODULE_FILES := $(sort $(filter-out $(__ALMAKE_HIDDEN_MODULE_FILES) $(ALMAKE_DIRECTORY_PATH)/mk/common.mk,$(__ALMAKE_MK_CONTENT)))

override __ALMAKE_SCAN_EXCLUDE_MAKEFILES_CSV = $(call almake-join-comma,$(call almake-disabled-module-files,$(__ALMAKE_MODULE_FILES)))
override __ALMAKE_HELP_FILE_LIST_CSV = $(call almake-join-comma,$(MAKEFILE_LIST))

ifneq ($(__ALMAKE_ENV_MAKE_RULE_ENABLED),)
$(ALMAKE_ENV_FILE):
	mkdir -p $(dir $(ALMAKE_ENV_FILE))
	$(call almake-gen-env-list,ALMAKE_DIRECTORY_PATH ALMAKE_ENV_FILE ALMAKE_SCAN_INCLUDE_DIRS_CSV ALMAKE_SCAN_INCLUDE_GLOBS_CSV ALMAKE_SCAN_EXCLUDE_DIRS_CSV ALMAKE_SCAN_EXCLUDE_GLOBS_CSV __ALMAKE_SCAN_EXCLUDE_MAKEFILES_CSV) bash $(__ALMAKE_ENV_MAKE_SCRIPT) bootstrap
endif

override __ALMAKE_ENV_MAKE_AVAILABLE := $(if $(wildcard $(ALMAKE_ENV_FILE)),1,)
override __ALMAKE_ENV_MAKE_VALIDATION_ERROR := $(if $(__ALMAKE_ENV_MAKE_AVAILABLE),$(shell $(call almake-gen-env-list,ALMAKE_DIRECTORY_PATH ALMAKE_ENV_FILE) bash $(__ALMAKE_ENV_MAKE_SCRIPT) validate 2>&1 || true),)
$(if $(__ALMAKE_ENV_MAKE_VALIDATION_ERROR),$(error $(__ALMAKE_ENV_MAKE_VALIDATION_ERROR)))
-include $(ALMAKE_ENV_FILE)

ALMAKE_SCAN_INCLUDE_DIRS_CSV ?=
ALMAKE_SCAN_EXCLUDE_DIRS_CSV ?=
ALMAKE_SCAN_INCLUDE_GLOBS_CSV ?=
ALMAKE_SCAN_EXCLUDE_GLOBS_CSV ?=
ALMAKE_GLOBAL_MAKEFLAGS ?= --always-make --silent
override MAKEFLAGS += $(ALMAKE_GLOBAL_MAKEFLAGS)

###

help: ## Show available targets
	$(call almake-gen-env-list,__ALMAKE_COMMAND_LINE_VARIABLES __ALMAKE_HELP_FILE_LIST_CSV ALMAKE_MAKE_BIN) bash $(__ALMAKE_HELP_SCRIPT)

###

endif
