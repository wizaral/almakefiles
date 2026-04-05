#!/usr/bin/env bash

assert_env_make_validation_failure() {
	local fixture_dir="$1"
	local expected_reason="$2"
	local env_make_path="$fixture_dir/almakefiles/.env.mk"
	local output
	local status

	set +e
	output="$(run_make "$fixture_dir" help 2>&1)"
	status=$?
	set -e

	assert_nonzero_exit "$status" "invalid .env.mk exit status"
	assert_contains "$output" "Invalid $env_make_path:1:"
	assert_contains "$output" "$expected_reason"
}

test_env_make_bootstrap_skips_duplicate_defaults_with_warning() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/alpha.mk" <<'EOF'
DUPLICATE_VAR ?= one
UNIQUE_VAR ?= unique
EOF

	cat >"$fixture_dir/beta.mk" <<'EOF'
DUPLICATE_VAR ?= two
EOF

	output="$(run_make "$fixture_dir" help 2>&1)"

	assert_file_exists "$fixture_dir/almakefiles/.env.mk"
	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "UNIQUE_VAR = unique"
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "DUPLICATE_VAR ="
	assert_contains "$output" "Skipping duplicate ?= default for DUPLICATE_VAR"
	assert_contains "$output" "alpha.mk:1"
	assert_contains "$output" "beta.mk:1"
	assert_contains "$output" "try 'make var.debug' for more info"
}

test_env_make_bootstrap_excludes_hidden_make_files() {
	local fixture_dir

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/visible.mk" <<'EOF'
VISIBLE_MK_VAR ?= visible-mk
EOF

	cat >"$fixture_dir/visible.makefile" <<'EOF'
VISIBLE_MAKEFILE_VAR ?= visible-makefile
EOF

	cat >"$fixture_dir/.hidden.mk" <<'EOF'
HIDDEN_MK_VAR ?= hidden-mk
EOF

	cat >"$fixture_dir/.hidden.makefile" <<'EOF'
HIDDEN_MAKEFILE_VAR ?= hidden-makefile
EOF

	cat >"$fixture_dir/.mk" <<'EOF'
EXACT_HIDDEN_MK_VAR ?= exact-hidden-mk
EOF

	cat >"$fixture_dir/.makefile" <<'EOF'
EXACT_HIDDEN_MAKEFILE_VAR ?= exact-hidden-makefile
EOF

	run_make "$fixture_dir" help >/dev/null 2>&1

	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "VISIBLE_MK_VAR = visible-mk"
	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "VISIBLE_MAKEFILE_VAR = visible-makefile"
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "HIDDEN_MK_VAR = hidden-mk"
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "HIDDEN_MAKEFILE_VAR = hidden-makefile"
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "EXACT_HIDDEN_MK_VAR = exact-hidden-mk"
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "EXACT_HIDDEN_MAKEFILE_VAR = exact-hidden-makefile"
}

test_env_sync_env_make_appends_only_missing_defaults() {
	local fixture_dir

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/project.mk" <<'EOF'
FIRST_VAR ?= one
EOF

	bootstrap_env_make "$fixture_dir"

	cat >"$fixture_dir/almakefiles/.env.mk" <<'EOF'
FIRST_VAR = custom
# user-owned note
EOF

	cat >"$fixture_dir/project-extra.mk" <<'EOF'
SECOND_VAR ?= two
EOF

	run_make "$fixture_dir" env.sync-env.mk

	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "FIRST_VAR = custom"
	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "# user-owned note"
	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "SECOND_VAR = two"
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "FIRST_VAR = one"
}

test_env_reinit_env_make_rebuilds_from_example_and_defaults() {
	local fixture_dir
	local env_make_contents
	local mode

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/project.mk" <<'EOF'
PROJECT_VAR ?= project-default
EOF

	bootstrap_env_make "$fixture_dir"

	cat >"$fixture_dir/almakefiles/.env.mk" <<'EOF'
BROKEN = 1
EOF
	chmod 640 "$fixture_dir/almakefiles/.env.mk"

	run_make "$fixture_dir" env.reinit-env.mk

	env_make_contents="$(cat "$fixture_dir/almakefiles/.env.mk")"
	assert_contains "$env_make_contents" "PROJECT_VAR = project-default"
	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "PROJECT_VAR = project-default"
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "BROKEN = 1"
	mode="$(stat -c '%a' "$fixture_dir/almakefiles/.env.mk")"
	assert_equals "$mode" "640" "reinitialized env make mode"
}

test_debug_full_excludes_hidden_local_make_files() {
	local fixture_dir
	local debug_full_output

	eval "$(setup_fixture fixture_dir)"

	bootstrap_env_make "$fixture_dir"

	cat >"$fixture_dir/almakefiles/.env.mk" <<'EOF'
LOCAL_SECRET = top-secret
VISIBLE_VAR = visible
EOF

	cat >"$fixture_dir/almakefiles/.local.makefile" <<'EOF'
LOCAL_SECRET_FROM_MAKEFILE = second-secret
EOF

	cat >"$fixture_dir/almakefiles/.mk" <<'EOF'
EXACT_LOCAL_SECRET_MK = third-secret
EOF

	cat >"$fixture_dir/almakefiles/.makefile" <<'EOF'
EXACT_LOCAL_SECRET_MAKEFILE = fourth-secret
EOF

	debug_full_output="$(
		run_make "$fixture_dir" var.debug-full 2>&1
	)"

	assert_contains "$debug_full_output" "__ALMAKE_DECLARED_ENV_FILES"
	assert_not_contains "$debug_full_output" "LOCAL_SECRET"
	assert_not_contains "$debug_full_output" "LOCAL_SECRET_FROM_MAKEFILE"
	assert_not_contains "$debug_full_output" "EXACT_LOCAL_SECRET_MK"
	assert_not_contains "$debug_full_output" "EXACT_LOCAL_SECRET_MAKEFILE"
}

test_env_make_accepts_supported_assignment_forms_and_comments() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/makefile" <<'EOF'
include almakefiles/include.mk

print:
	@printf '%s\n' '$(ALMAKE_PUBLIC_EQ)|$(ALMAKE_PUBLIC_IMMEDIATE)|$(ALMAKE_PUBLIC_POSIX)|$(ALMAKE_PUBLIC_APPEND)|$(PROJECT_VALUE)'
EOF

	cat >"$fixture_dir/almakefiles/.env.mk" <<'EOF'
# user-owned comment

ALMAKE_PUBLIC_EQ = eq
ALMAKE_PUBLIC_IMMEDIATE := $(ALMAKE_PUBLIC_EQ)-immediate
ALMAKE_PUBLIC_POSIX ::= $(shell printf 'posix')
ALMAKE_PUBLIC_APPEND = append
ALMAKE_PUBLIC_APPEND += -ok
PROJECT_VALUE = project
EOF

	output="$(run_make "$fixture_dir" print 2>&1)"

	assert_contains "$output" "eq|eq-immediate|posix|append -ok|project"
}

test_env_make_rejects_invalid_directives_and_names() {
	local fixture_dir
	local case_entry
	local line
	local expected_reason

	for case_entry in \
		"override ALMAKE_BAD = 1|override directives are not allowed in .env.mk" \
		"export ALMAKE_BAD = 1|export directives are not allowed in .env.mk" \
		"private ALMAKE_BAD = 1|private directives are not allowed in .env.mk" \
		"undefine ALMAKE_BAD|undefine directives are not allowed in .env.mk" \
		"define ALMAKE_BAD|define blocks are not allowed in .env.mk" \
		"endef|define blocks are not allowed in .env.mk" \
		"ifdef ALMAKE_BAD|conditional directives are not allowed in .env.mk" \
		"ifndef ALMAKE_BAD|conditional directives are not allowed in .env.mk" \
		"ifeq (a,b)|conditional directives are not allowed in .env.mk" \
		"ifneq (a,b)|conditional directives are not allowed in .env.mk" \
		"else|conditional directives are not allowed in .env.mk" \
		"endif|conditional directives are not allowed in .env.mk" \
		"include local.mk|include directives are not allowed in .env.mk" \
		"-include local.mk|include directives are not allowed in .env.mk" \
		"sinclude local.mk|include directives are not allowed in .env.mk" \
		"ALMAKE_BAD ?= 1|?= assignments are not allowed in .env.mk" \
		"ALMAKE_BAD != printf hi|!= assignments are not allowed in .env.mk" \
		"target: prerequisite|targets and rules are not allowed in .env.mk" \
		"__ALMAKE_BAD = 1|__ALMAKE_* variables are not allowed in .env.mk" \
		"MAKEFLAGS = -j8|GNU Make system variables are not allowed in .env.mk"
	do
		eval "$(setup_fixture fixture_dir)"
		line="${case_entry%%|*}"
		expected_reason="${case_entry#*|}"

		printf '%s\n' "$line" >"$fixture_dir/almakefiles/.env.mk"

		assert_env_make_validation_failure "$fixture_dir" "$expected_reason"
	done
}

test_env_make_bootstrap_skips_internal_and_system_question_defaults() {
	local fixture_dir

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/project.mk" <<'EOF'
PROJECT_ALLOWED ?= allowed
__ALMAKE_INTERNAL ?= nope
MAKEFLAGS ?= -j8
EOF

	run_make "$fixture_dir" help >/dev/null 2>&1

	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "PROJECT_ALLOWED = allowed"
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "__ALMAKE_INTERNAL = nope"
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "MAKEFLAGS = -j8"
}

test_env_make_bootstrap_reads_root_makefile_symlink() {
	local fixture_dir

	eval "$(setup_fixture fixture_dir)"

	rm -f "$fixture_dir/makefile"
	cat >"$fixture_dir/root-entrypoint" <<'EOF'
ROOT_SYMLINK_VAR ?= from-root-symlink
include almakefiles/include.mk
EOF
	ln -s root-entrypoint "$fixture_dir/makefile"

	run_make "$fixture_dir" help >/dev/null 2>&1

	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "ROOT_SYMLINK_VAR = from-root-symlink"
}

test_env_make_bootstrap_reads_root_gnumakefile() {
	local fixture_dir

	eval "$(setup_fixture fixture_dir)"

	rm -f "$fixture_dir/makefile"
	cat >"$fixture_dir/GNUmakefile" <<'EOF'
ROOT_GNUMAKEFILE_VAR ?= from-gnumakefile
include almakefiles/include.mk
EOF

	(
		cd "$fixture_dir" || exit 1
		PATH="$fixture_dir/bin:$PATH" make -f GNUmakefile help >/dev/null 2>&1
	)

	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "ROOT_GNUMAKEFILE_VAR = from-gnumakefile"
}

test_debug_targets_show_effective_winners() {
	local fixture_dir
	local debug_output
	local debug_full_output

	eval "$(setup_fixture fixture_dir)"

	bootstrap_env_make "$fixture_dir"

	debug_output="$(
		run_make "$fixture_dir" ALMAKE_NO_AUTO_ENV_INIT=1 ALMAKE_ENV_COMPOSE_FILES_CSV=.env.local var.debug 2>&1
	)"
	debug_full_output="$(
		run_make "$fixture_dir" var.debug-full 2>&1
	)"

	assert_contains "$debug_output" "ALMAKE_ENV_COMPOSE_FILES_CSV"
	assert_contains "$debug_output" "origin: command line"
	assert_not_contains "$debug_output" "__ALMAKE_DECLARED_ENV_FILES"
	assert_contains "$debug_full_output" "__ALMAKE_DECLARED_ENV_FILES"
	assert_contains "$debug_full_output" "almakefiles/mk/env.mk"
}

test_env_make_scan_exclude_dirs_csv_filters_matching_directories() {
	local fixture_dir

	eval "$(setup_fixture fixture_dir)"

	mkdir -p "$fixture_dir/almakefiles/local" "$fixture_dir/extras"

	cat >"$fixture_dir/kept.mk" <<'EOF'
KEPT_SCAN_VAR ?= kept
EOF

	cat >"$fixture_dir/almakefiles/local/blocked.mk" <<'EOF'
BLOCKED_DEFAULT_DIR_VAR ?= blocked-default-dir
EOF

	cat >"$fixture_dir/extras/blocked.makefile" <<'EOF'
BLOCKED_EXTRA_DIR_VAR ?= blocked-extra-dir
EOF

	run_make "$fixture_dir" \
		ALMAKE_SCAN_INCLUDE_DIRS_CSV=extras \
		ALMAKE_SCAN_EXCLUDE_DIRS_CSV=almakefiles/local,extras \
		help >/dev/null 2>&1

	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "KEPT_SCAN_VAR = kept"
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "BLOCKED_DEFAULT_DIR_VAR = blocked-default-dir"
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "BLOCKED_EXTRA_DIR_VAR = blocked-extra-dir"
}

test_env_make_scan_exclude_globs_csv_filters_matching_paths() {
	local fixture_dir

	eval "$(setup_fixture fixture_dir)"

	mkdir -p "$fixture_dir/extras"

	cat >"$fixture_dir/kept.mk" <<'EOF'
KEPT_GLOB_VAR ?= kept-glob
EOF

	cat >"$fixture_dir/blocked-root.makefile" <<'EOF'
BLOCKED_ROOT_GLOB_VAR ?= blocked-root-glob
EOF

	cat >"$fixture_dir/extras/blocked-extra.mk" <<'EOF'
BLOCKED_EXTRA_GLOB_VAR ?= blocked-extra-glob
EOF

	run_make "$fixture_dir" \
		ALMAKE_SCAN_INCLUDE_GLOBS_CSV='extras/**/*.mk' \
		ALMAKE_SCAN_EXCLUDE_GLOBS_CSV='blocked-root.makefile,extras/**/*.mk' \
		help >/dev/null 2>&1

	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "KEPT_GLOB_VAR = kept-glob"
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "BLOCKED_ROOT_GLOB_VAR = blocked-root-glob"
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "BLOCKED_EXTRA_GLOB_VAR = blocked-extra-glob"
}

test_env_make_bootstrap_excludes_disabled_module_files() {
	local fixture_dir

	eval "$(setup_fixture fixture_dir)"

	run_make "$fixture_dir" \
		ALMAKE_NO_AUTO_ENV_INIT=1 \
		ALMAKE_DISABLE_MODULE_DOCKER_COMPOSE=1 \
		ALMAKE_DISABLE_MODULE_GIT=1 \
		help >/dev/null 2>&1

	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "ALMAKE_DOCKER_COMPOSE_UID ="
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "ALMAKE_ENV_COMPOSE_FILES_CSV = .env"
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "ALMAKE_DOCKER_COMPOSE_FILES_CSV = compose.yaml"
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "ALMAKE_GIT_CLEAN_EXCLUDES_CSV = \$(ALMAKE_ENV_FILE)"
}

test_env_make_bootstrap_does_not_scan_non_module_dropin_makefiles() {
	local fixture_dir

	eval "$(setup_fixture fixture_dir)"

	mkdir -p "$fixture_dir/almakefiles/tests"
	cat >"$fixture_dir/almakefiles/tests/leak.mk" <<'EOF'
LEAKED_FROM_TESTS ?= leak
EOF

	run_make "$fixture_dir" help >/dev/null 2>&1

	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "LEAKED_FROM_TESTS = leak"
}

test_auto_discovered_module_defaults_follow_module_enablement() {
	local fixture_dir

	eval "$(setup_fixture fixture_dir)"

	write_auto_module_fixture "$fixture_dir"

	run_make "$fixture_dir" ALMAKE_NO_AUTO_ENV_INIT=1 help >/dev/null 2>&1
	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "ALMAKE_FEATURE_TOGGLE_VALUE = feature-toggle-default"

	rm -f "$fixture_dir/almakefiles/.env.mk"

	run_make "$fixture_dir" \
		ALMAKE_NO_AUTO_ENV_INIT=1 \
		ALMAKE_DISABLE_MODULE_FEATURE_TOGGLE=1 \
		help >/dev/null 2>&1
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "ALMAKE_FEATURE_TOGGLE_VALUE = feature-toggle-default"
}

test_dry_run_debug_targets_print_recipes_without_executing_scripts() {
	local fixture_dir
	local debug_output
	local debug_full_output

	eval "$(setup_fixture fixture_dir)"

	debug_output="$(
		run_make "$fixture_dir" -n var.debug 2>&1
	)"
	debug_full_output="$(
		run_make "$fixture_dir" -n var.debug-full 2>&1
	)"

	assert_contains "$debug_output" "ALMAKE_MAKE_BIN='make'"
	assert_contains "$debug_output" "ALMAKE_ENV_FILE='almakefiles/.env.mk'"
	assert_contains "$debug_output" "ALMAKE_SCAN_INCLUDE_DIRS_CSV=''"
	assert_contains "$debug_output" "ALMAKE_SCAN_INCLUDE_GLOBS_CSV=''"
	assert_contains "$debug_output" "ALMAKE_SCAN_EXCLUDE_DIRS_CSV=''"
	assert_contains "$debug_output" "ALMAKE_SCAN_EXCLUDE_GLOBS_CSV=''"
	assert_not_contains "$debug_output" "ENV_MAKE_SCRIPT_ARGS="
	assert_not_contains "$debug_output" "origin:"
	assert_not_contains "$debug_output" "source:"

	assert_contains "$debug_full_output" "ALMAKE_MAKE_BIN='make'"
	assert_contains "$debug_full_output" "ALMAKE_ENV_FILE='almakefiles/.env.mk'"
	assert_contains "$debug_full_output" "ALMAKE_SCAN_INCLUDE_DIRS_CSV=''"
	assert_contains "$debug_full_output" "ALMAKE_SCAN_INCLUDE_GLOBS_CSV=''"
	assert_contains "$debug_full_output" "ALMAKE_SCAN_EXCLUDE_DIRS_CSV=''"
	assert_contains "$debug_full_output" "ALMAKE_SCAN_EXCLUDE_GLOBS_CSV=''"
	assert_contains "$debug_full_output" "debug --full"
	assert_not_contains "$debug_full_output" "ENV_MAKE_SCRIPT_ARGS="
	assert_not_contains "$debug_full_output" "origin:"
	assert_not_contains "$debug_full_output" "source:"
}

test_first_make_with_cli_env_make_override_creates_override_and_continues() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	output="$(
		run_make "$fixture_dir" ALMAKE_ENV_FILE=.env.lol help 2>&1
	)"

	assert_file_exists "$fixture_dir/.env.lol"
	assert_file_exists "$fixture_dir/.env"
	assert_file_not_exists "$fixture_dir/almakefiles/.env.mk"
	assert_contains "$output" "Created .env.lol"
	assert_contains "$output" "compose.config"
}

test_first_make_with_quoted_cli_env_make_override_creates_override_and_continues() {
	local fixture_dir
	local output
	local env_make_path

	eval "$(setup_fixture fixture_dir)"
	env_make_path="$fixture_dir/.env.o'hare"

	output="$(
		run_make "$fixture_dir" "ALMAKE_ENV_FILE=.env.o'hare" help 2>&1
	)"

	assert_file_exists "$env_make_path"
	assert_file_exists "$fixture_dir/.env"
	assert_file_not_exists "$fixture_dir/almakefiles/.env.mk"
	assert_contains "$output" "Created .env.o'hare"
	assert_contains "$output" "compose.config"
	assert_not_contains "$output" "Syntax error:"
}

test_first_make_with_quoted_scan_include_dir_continues() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	mkdir -p "$fixture_dir/dir'o"
	cat >"$fixture_dir/dir'o/project.mk" <<'EOF'
TEST_VAR ?= ok
EOF

	output="$(
		run_make "$fixture_dir" "ALMAKE_SCAN_INCLUDE_DIRS_CSV=dir'o" help 2>&1
	)"

	assert_file_exists "$fixture_dir/almakefiles/.env.mk"
	assert_file_exists "$fixture_dir/.env"
	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "TEST_VAR = ok"
	assert_contains "$output" "Created almakefiles/.env.mk"
	assert_contains "$output" "compose.config"
	assert_not_contains "$output" "Syntax error:"
}

test_additional_makeflags_can_be_overridden_externally() {
	local fixture_dir
	local first_stamp
	local second_stamp

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/makefile" <<'EOF'
include almakefiles/include.mk

stamp:
	date +%s > stamp

build: stamp
	cat stamp
EOF

	run_make "$fixture_dir" ALMAKE_GLOBAL_MAKEFLAGS= build >/dev/null 2>&1
	first_stamp="$(cat "$fixture_dir/stamp")"

	sleep 1

	run_make "$fixture_dir" ALMAKE_GLOBAL_MAKEFLAGS= build >/dev/null 2>&1
	second_stamp="$(cat "$fixture_dir/stamp")"

	assert_equals "$second_stamp" "$first_stamp" "stamp value with ALMAKE_GLOBAL_MAKEFLAGS override"
}

test_public_computed_vars_ignore_external_overrides() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	output="$(
		run_make "$fixture_dir" \
			ALMAKE_DIRECTORY_PATH=broken/path \
			ALMAKE_MAKE_BIN=broken-make \
			var.debug-full 2>&1
	)"

	assert_contains "$output" "ALMAKE_DIRECTORY_PATH"
	assert_contains "$output" "  value: almakefiles"
	assert_contains "$output" "ALMAKE_MAKE_BIN"
	assert_contains "$output" "  value: make"
}

test_debug_reports_canonical_directory_path_for_nested_dropin() {
	local fixture_dir
	local output

	eval "$(setup_fixture_with_dropin_path fixture_dir "tools/dev-layer" "include ././tools/../tools/dev-layer/include.mk")"

	output="$(run_make "$fixture_dir" var.debug-full 2>&1)"

	assert_contains "$output" "ALMAKE_DIRECTORY_PATH"
	assert_contains "$output" "  value: tools/dev-layer"
	assert_contains "$output" "ALMAKE_ENV_FILE"
	assert_contains "$output" "  value: tools/dev-layer/.env.mk"
}

test_debug_reports_absolute_directory_path_for_outside_dropin() {
	local fixture_dir
	local output
	local expected_path

	eval "$(setup_fixture_with_dropin_path fixture_dir "../shared/dev-layer" "include ././../shared/./dev-layer/include.mk")"
	expected_path="$(realpath "$fixture_dir/../shared/dev-layer")"

	output="$(run_make "$fixture_dir" var.debug-full 2>&1)"

	assert_contains "$output" "ALMAKE_DIRECTORY_PATH"
	assert_contains "$output" "  value: $expected_path"
	assert_contains "$output" "ALMAKE_ENV_FILE"
	assert_contains "$output" "  value: .env.mk"
}

test_env_sync_env_make_respects_existing_colon_equals_assignment() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/project.mk" <<'EOF'
FIRST_VAR ?= one
EOF

	bootstrap_env_make "$fixture_dir"

	cat >"$fixture_dir/almakefiles/.env.mk" <<'EOF'
FIRST_VAR := custom
EOF

	cat >"$fixture_dir/project-extra.mk" <<'EOF'
SECOND_VAR ?= two
EOF

	output="$(run_make "$fixture_dir" env.sync-env.mk 2>&1)"

	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "FIRST_VAR := custom"
	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "SECOND_VAR = two"
	assert_file_not_contains "$fixture_dir/almakefiles/.env.mk" "FIRST_VAR = one"
	assert_not_contains "$output" "Appended FIRST_VAR to almakefiles/.env.mk"
}

run_env_make_suite() {
	test_env_make_bootstrap_skips_duplicate_defaults_with_warning
	test_env_make_bootstrap_excludes_hidden_make_files
	test_env_make_accepts_supported_assignment_forms_and_comments
	test_env_make_rejects_invalid_directives_and_names
	test_env_make_bootstrap_skips_internal_and_system_question_defaults
	test_env_make_bootstrap_reads_root_makefile_symlink
	test_env_make_bootstrap_reads_root_gnumakefile
	test_env_sync_env_make_appends_only_missing_defaults
	test_env_reinit_env_make_rebuilds_from_example_and_defaults
	test_debug_full_excludes_hidden_local_make_files
	test_debug_targets_show_effective_winners
	test_env_make_scan_exclude_dirs_csv_filters_matching_directories
	test_env_make_scan_exclude_globs_csv_filters_matching_paths
	test_env_make_bootstrap_excludes_disabled_module_files
	test_env_make_bootstrap_does_not_scan_non_module_dropin_makefiles
	test_auto_discovered_module_defaults_follow_module_enablement
	test_dry_run_debug_targets_print_recipes_without_executing_scripts
	test_first_make_with_cli_env_make_override_creates_override_and_continues
	test_first_make_with_quoted_cli_env_make_override_creates_override_and_continues
	test_first_make_with_quoted_scan_include_dir_continues
	test_additional_makeflags_can_be_overridden_externally
	test_public_computed_vars_ignore_external_overrides
	test_debug_reports_canonical_directory_path_for_nested_dropin
	test_debug_reports_absolute_directory_path_for_outside_dropin
	test_env_sync_env_make_respects_existing_colon_equals_assignment
}
