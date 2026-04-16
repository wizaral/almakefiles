ifeq ($(ALMKFS_DISABLE_MODULE_GIT),1)
else ifndef __ALMKFS_INCLUDE_GUARD_GIT
override __ALMKFS_INCLUDE_GUARD_GIT = 1
ALMKFS_DISABLE_MODULE_GIT ?=

$(eval $(call almkfs-target-require,git,))

###

ALMKFS_GIT_CLEAN_EXCLUDES_CSV ?= $(call almkfs-join-comma,$(sort $(ALMKFS_ENV_FILE) $(__ALMKFS_ALL_ENV_FILES)))
ALMKFS_GIT_CLEAN_FLAGS ?= -f -d -x
override __ALMKFS_GIT_CLEAN_EXCLUDES_ARGS := $(call almkfs-split-comma,$(ALMKFS_GIT_CLEAN_EXCLUDES_CSV),-e ,)

git.clean: common.ensure-git ## Remove all untracked files/directories except excluded local files
	git clean $(ALMKFS_GIT_CLEAN_FLAGS) $(__ALMKFS_GIT_CLEAN_EXCLUDES_ARGS)

git.dry-clean: common.ensure-git ## Preview files/directories that would be removed by clean
	git clean $(ALMKFS_GIT_CLEAN_FLAGS) -n $(__ALMKFS_GIT_CLEAN_EXCLUDES_ARGS)

endif
