ifeq ($(ALMAKE_DISABLE_MODULE_GIT),1)
else ifndef __ALMAKE_INCLUDE_GUARD_GIT
override __ALMAKE_INCLUDE_GUARD_GIT = 1
ALMAKE_DISABLE_MODULE_GIT ?=

$(eval $(call almake-target-require,git,))

###

ALMAKE_GIT_CLEAN_EXCLUDES_CSV ?= $(ALMAKE_ENV_FILE)
ALMAKE_GIT_CLEAN_FLAGS ?= -f -d -x
override __ALMAKE_GIT_CLEAN_EXCLUDES_ARGS := $(call almake-split-comma,$(ALMAKE_GIT_CLEAN_EXCLUDES_CSV),-e ,)

git.clean: common.ensure-git ## Remove all untracked files/directories except excluded local files
	git clean $(ALMAKE_GIT_CLEAN_FLAGS) $(__ALMAKE_GIT_CLEAN_EXCLUDES_ARGS)

git.dry-clean: common.ensure-git ## Preview files/directories that would be removed by clean
	git clean $(ALMAKE_GIT_CLEAN_FLAGS) -n $(__ALMAKE_GIT_CLEAN_EXCLUDES_ARGS)

endif
