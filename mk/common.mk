ifndef __ALMKFS_INCLUDE_GUARD_COMMON
override __ALMKFS_INCLUDE_GUARD_COMMON = 1

override .DEFAULT_GOAL := help
override ALMKFS_MAKE_BIN := $(MAKE)

###

override __ALMKFS_EMPTY :=
override __ALMKFS_SPACE := $(__ALMKFS_EMPTY) $(__ALMKFS_EMPTY)
override __ALMKFS_COMMA := ,
override __ALMKFS_SQUOTE := '
override __ALMKFS_SQUOTE_ESCAPE := '"'"'

# 1 - comma separated list, 2 - item prefix, 3 - item suffix
override define almkfs-split-comma
$(foreach item,$(subst $(__ALMKFS_COMMA), ,$1),$2$(item)$3)
endef

# 1 - whitespace separated list
override define almkfs-join-comma
$(subst $(__ALMKFS_SPACE),$(__ALMKFS_COMMA),$(strip $1))
endef

# 1 - raw value
override define almkfs-shell-quote
'$(subst $(__ALMKFS_SQUOTE),$(__ALMKFS_SQUOTE_ESCAPE),$1)'
endef

# 1 - variable name
override define almkfs-pass-env
$(patsubst %,%=$(call almkfs-shell-quote,$($1)),$1)
endef

# 1 - comma separated list of variable names
override define almkfs-gen-env-list
$(foreach v,$(call almkfs-split-comma,$1,,),$(call almkfs-pass-env,$v))
endef

# 1 - whitespace separated list of needles, 2 - haystack
override define almkfs-findstring-any
$(strip $(foreach needle,$1,$(findstring $(needle),$2)))
endef

# 1 - raw value
override define almkfs-upper-snake
$(shell printf '%s\n' $(call almkfs-shell-quote,$1) | tr '[:lower:]-' '[:upper:]_')
endef

# 1 - module file path
override define almkfs-module-name
$(basename $(notdir $1))
endef

# 1 - module file path
override define almkfs-module-disable-var
ALMKFS_DISABLE_MODULE_$(call almkfs-upper-snake,$(call almkfs-module-name,$1))
endef

# 1 - whitespace separated list of module file paths
override define almkfs-active-module-files
$(strip $(foreach module,$1,$(if $(filter 1,$($(call almkfs-module-disable-var,$(module)))),,$(module))))
endef

# 1 - whitespace separated list of module file paths
override define almkfs-disabled-module-files
$(strip $(foreach module,$1,$(if $(filter 1,$($(call almkfs-module-disable-var,$(module)))),$(module),)))
endef

# 1 - command to check, 2 - tool name, 3 - message
override define almkfs-require-base
$1 || (echo "$2 is required$3" && exit 1)
endef

# 1 - command to check, 2 - tool name, 3 - message
override define almkfs-target-require-base
common.ensure-$2: ## Ensures $2 is installed
	$(call almkfs-require-base,$1,$2,$3)
endef

# 1 - tool name, 2 - message
override define almkfs-require
$(call almkfs-require-base,command -v $1 >/dev/null 2>&1,$1,$2)
endef

# 1 - tool name, 2 - message
override define almkfs-target-require
common.ensure-$1: ## Ensures $1 is installed
	$(call almkfs-require,$1,$2)
endef

# 1 - token
override define almkfs-query-token-has-attached-argument
$(if $(or $(filter -C% -f% -I% -o% -W% -O% -j% -l%,$1),$(filter --directory=% --file=% --makefile=% --include-dir=% --old-file=% --assume-old=% --new-file=% --what-if=% --assume-new=% --eval=% --output-sync=% --jobs=% --load-average=% --max-load=%,$1)),1,)
endef

# 1 - current token, 2 - next token
override define almkfs-query-token-consumes-next
$(if $(filter -C -f -I -o -W --directory --file --makefile --include-dir --old-file --assume-old --new-file --what-if --assume-new --eval,$1),1,$(if $(filter -O -j -l --output-sync --jobs --load-average --max-load,$1),$(if $(and $2,$(if $(filter -% --%,$2),,1)),1,),))
endef

# 1 - token
override define almkfs-query-token-is-scan-candidate
$(if $(or $(filter --%,$1),$(filter %=%,$1),$(call almkfs-query-token-has-attached-argument,$1),$(filter -C -f -I -o -W -O -j -l --directory --file --makefile --include-dir --old-file --assume-old --new-file --what-if --assume-new --eval --output-sync --jobs --load-average --max-load,$1)),,$1)
endef

# 1 - remaining MAKEFLAGS tokens
override define almkfs-query-scan-tokens
$(strip $(if $(strip $1),$(call almkfs-query-scan-tokens-step,$(firstword $1),$(word 2,$1),$(wordlist 2,$(words $1),$1)),))
endef

# 1 - current token, 2 - next token, 3 - remaining tokens after current
override define almkfs-query-scan-tokens-step
$(strip $(call almkfs-query-token-is-scan-candidate,$1) $(call almkfs-query-scan-tokens,$(if $(call almkfs-query-token-consumes-next,$1,$2),$(wordlist 2,$(words $3),$3),$3)))
endef

###

override __ALMKFS_COMMON_MAKEFILE_FILE := $(lastword $(MAKEFILE_LIST))
override __ALMKFS_COMMON_MAKEFILE := $(realpath $(__ALMKFS_COMMON_MAKEFILE_FILE))
override __ALMKFS_MK_DIRECTORY := $(patsubst %/,%,$(dir $(__ALMKFS_COMMON_MAKEFILE_FILE)))
override __ALMKFS_DIRECTORY_REALPATH := $(realpath $(__ALMKFS_MK_DIRECTORY)/..)
override __ALMKFS_PROJECT_ROOT_REALPATH := $(shell pwd -P)

override ALMKFS_DIRECTORY_PATH := $(shell realpath --relative-base=$(call almkfs-shell-quote,$(__ALMKFS_PROJECT_ROOT_REALPATH)) --relative-to=$(call almkfs-shell-quote,$(__ALMKFS_PROJECT_ROOT_REALPATH)) $(call almkfs-shell-quote,$(__ALMKFS_DIRECTORY_REALPATH)))

override __ALMKFS_DIRECTORY_INSIDE_PROJECT := $(if $(filter /%,$(ALMKFS_DIRECTORY_PATH)),,1)
override __ALMKFS_EXPECTED_INCLUDE_MAKEFILE := $(ALMKFS_DIRECTORY_PATH)/include.mk
override __ALMKFS_EXPECTED_COMMON_MAKEFILE := $(ALMKFS_DIRECTORY_PATH)/mk/common.mk
override __ALMKFS_ENV_INIT_SCRIPT := $(ALMKFS_DIRECTORY_PATH)/scripts/env-init.sh
override __ALMKFS_ENV_MAKE_SCRIPT := $(ALMKFS_DIRECTORY_PATH)/scripts/env-make.sh
override __ALMKFS_HELP_SCRIPT := $(ALMKFS_DIRECTORY_PATH)/scripts/help.sh
override __ALMKFS_DEFAULT_ENV_FILE := $(if $(__ALMKFS_DIRECTORY_INSIDE_PROJECT),$(if $(filter .,$(ALMKFS_DIRECTORY_PATH)),.env.mk,$(ALMKFS_DIRECTORY_PATH)/.env.mk),.env.mk)

ALMKFS_ENV_FILE ?= $(__ALMKFS_DEFAULT_ENV_FILE)

$(if $(wildcard $(__ALMKFS_EXPECTED_INCLUDE_MAKEFILE)),,$(error Invalid almakefiles layout: missing $(__ALMKFS_EXPECTED_INCLUDE_MAKEFILE)))
$(if $(wildcard $(__ALMKFS_EXPECTED_COMMON_MAKEFILE)),,$(error Invalid almakefiles layout: missing $(__ALMKFS_EXPECTED_COMMON_MAKEFILE)))
$(if $(filter $(__ALMKFS_COMMON_MAKEFILE),$(realpath $(__ALMKFS_EXPECTED_COMMON_MAKEFILE))),,$(error Invalid almakefiles layout: loaded $(__ALMKFS_COMMON_MAKEFILE) but expected $(__ALMKFS_EXPECTED_COMMON_MAKEFILE)))
$(if $(wildcard $(__ALMKFS_ENV_INIT_SCRIPT)),,$(error Invalid almakefiles layout: missing $(__ALMKFS_ENV_INIT_SCRIPT)))
$(if $(wildcard $(__ALMKFS_ENV_MAKE_SCRIPT)),,$(error Invalid almakefiles layout: missing $(__ALMKFS_ENV_MAKE_SCRIPT)))
$(if $(wildcard $(__ALMKFS_HELP_SCRIPT)),,$(error Invalid almakefiles layout: missing $(__ALMKFS_HELP_SCRIPT)))

###

override __ALMKFS_TOP_LEVEL := $(if $(filter 0,$(MAKELEVEL)),1,)
override __ALMKFS_QUERY_FLAGS := $(call almkfs-query-scan-tokens,$(strip $(MAKEFLAGS)))
override __ALMKFS_QUERY_MODE := $(if $(or $(filter --just-print --dry-run --recon --print-data-base --question,$(strip $(MAKEFLAGS))),$(call almkfs-findstring-any,n p q,$(__ALMKFS_QUERY_FLAGS))),1,)
override __ALMKFS_ENV_MAKE_RULE_ENABLED := $(if $(or $(__ALMKFS_QUERY_MODE),$(if $(__ALMKFS_TOP_LEVEL),,1)),,1)
override __ALMKFS_RAW_MAKEOVERRIDES := $(MAKEOVERRIDES)

override __ALMKFS_MK_CONTENT := $(wildcard $(ALMKFS_DIRECTORY_PATH)/mk/*.mk) $(wildcard $(ALMKFS_DIRECTORY_PATH)/mk/*.makefile)
override __ALMKFS_HIDDEN_MODULE_FILES := $(strip $(ALMKFS_DIRECTORY_PATH)/mk/.mk $(ALMKFS_DIRECTORY_PATH)/mk/.makefile $(wildcard $(ALMKFS_DIRECTORY_PATH)/mk/.*.mk) $(wildcard $(ALMKFS_DIRECTORY_PATH)/mk/.*.makefile))
override __ALMKFS_MODULE_FILES := $(sort $(filter-out $(__ALMKFS_HIDDEN_MODULE_FILES) $(ALMKFS_DIRECTORY_PATH)/mk/common.mk,$(__ALMKFS_MK_CONTENT)))

override __ALMKFS_SCAN_EXCLUDE_MAKEFILES_CSV = $(call almkfs-join-comma,$(call almkfs-disabled-module-files,$(__ALMKFS_MODULE_FILES)))
override __ALMKFS_HELP_FILE_LIST_CSV = $(call almkfs-join-comma,$(MAKEFILE_LIST))

ifneq ($(__ALMKFS_ENV_MAKE_RULE_ENABLED),)
$(ALMKFS_ENV_FILE):
	mkdir -p $(dir $(ALMKFS_ENV_FILE))
	$(call almkfs-gen-env-list,ALMKFS_DIRECTORY_PATH ALMKFS_ENV_FILE ALMKFS_SCAN_INCLUDE_DIRS_CSV ALMKFS_SCAN_INCLUDE_GLOBS_CSV ALMKFS_SCAN_EXCLUDE_DIRS_CSV ALMKFS_SCAN_EXCLUDE_GLOBS_CSV __ALMKFS_SCAN_EXCLUDE_MAKEFILES_CSV) bash $(__ALMKFS_ENV_MAKE_SCRIPT) bootstrap
endif

override __ALMKFS_ENV_MAKE_AVAILABLE := $(if $(wildcard $(ALMKFS_ENV_FILE)),1,)
override __ALMKFS_ENV_MAKE_VALIDATION_ERROR := $(if $(__ALMKFS_ENV_MAKE_AVAILABLE),$(shell $(call almkfs-gen-env-list,ALMKFS_DIRECTORY_PATH ALMKFS_ENV_FILE) bash $(__ALMKFS_ENV_MAKE_SCRIPT) validate 2>&1 || true),)
$(if $(__ALMKFS_ENV_MAKE_VALIDATION_ERROR),$(error $(__ALMKFS_ENV_MAKE_VALIDATION_ERROR)))
-include $(ALMKFS_ENV_FILE)

ALMKFS_SCAN_INCLUDE_DIRS_CSV ?=
ALMKFS_SCAN_EXCLUDE_DIRS_CSV ?=
ALMKFS_SCAN_INCLUDE_GLOBS_CSV ?=
ALMKFS_SCAN_EXCLUDE_GLOBS_CSV ?=
ALMKFS_GLOBAL_MAKEFLAGS ?= --always-make --silent
override MAKEFLAGS += $(ALMKFS_GLOBAL_MAKEFLAGS)

###

help: ## Show available targets
	$(call almkfs-gen-env-list,__ALMKFS_RAW_MAKEOVERRIDES __ALMKFS_HELP_FILE_LIST_CSV ALMKFS_MAKE_BIN) bash $(__ALMKFS_HELP_SCRIPT)

###

endif
