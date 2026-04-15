#!/usr/bin/env bash

test_almakefiles_recipes_do_not_use_raw_make() {
	local output

	output="$(
		cd "$REPO_ROOT" || exit 1
		# shellcheck disable=SC2016
		find . -type f \( -name '*.mk' -o -name '*.makefile' \) -print0 |
		xargs -0 awk '
			FNR == 1 { file = FILENAME }
			/^\t/ && ($0 ~ /\$\((MAKE)\)/ || $0 ~ /\$\{MAKE\}/) {
				printf "%s:%d:%s\n", file, FNR, $0
			}
		' 2>/dev/null
	)"

	if [[ -n "$output" ]]; then
		printf "Raw \$(MAKE) is forbidden in module recipes. Use \$(ALMKFS_MAKE_BIN) instead.\n" >&2
		printf 'Offending lines:\n%s\n' "$output" >&2
		exit 1
	fi
}

test_almakefiles_make_defines_use_kebab_case() {
	local output

	output="$(
		cd "$REPO_ROOT" || exit 1
		# shellcheck disable=SC2016
		find mk -type f \( -name '*.mk' -o -name '*.makefile' \) -print0 |
		xargs -0 awk '
			FNR == 1 { file = FILENAME }
			/^(override[[:space:]]+)?define[[:space:]]+/ {
				name = $NF
				if (name !~ /^almkfs(-[a-z0-9]+)+$/) {
					printf "%s:%d:%s\n", file, FNR, name
				}
			}
		' 2>/dev/null
	)"

	if [[ -n "$output" ]]; then
		printf "Make define helpers must use almkfs-prefixed kebab-case names.\n" >&2
		printf 'Offending defines:\n%s\n' "$output" >&2
		exit 1
	fi
}

test_runtime_layout_contains_expected_paths() {
	assert_file_exists "$REPO_ROOT/include.mk"
	assert_file_exists "$REPO_ROOT/mk/common.mk"
	assert_file_exists "$REPO_ROOT/mk/docker-compose.mk"
	assert_file_exists "$REPO_ROOT/mk/env.mk"
	assert_file_exists "$REPO_ROOT/mk/git.mk"
	assert_file_exists "$REPO_ROOT/scripts/env-init.sh"
	assert_file_exists "$REPO_ROOT/scripts/env-make.sh"
	assert_file_exists "$REPO_ROOT/scripts/help.sh"
}

test_test_runner_uses_split_suites() {
	local runner_contents

	assert_file_exists "$REPO_ROOT/tests/lib/test_helpers.sh"
	assert_file_exists "$REPO_ROOT/tests/suites/env-init-suite.sh"
	assert_file_exists "$REPO_ROOT/tests/suites/env-make-suite.sh"
	assert_file_exists "$REPO_ROOT/tests/suites/system-suite.sh"

	runner_contents="$(cat "$REPO_ROOT/tests/test_make_templates.sh")"

	assert_contains "$runner_contents" "lib/test_helpers.sh"
	assert_contains "$runner_contents" "suites/env-init-suite.sh"
	assert_contains "$runner_contents" "suites/env-make-suite.sh"
	assert_contains "$runner_contents" "suites/system-suite.sh"
	assert_not_contains "$runner_contents" "# shellcheck source="
}

test_git_clean_preserves_custom_env_make_file() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	(
		cd "$fixture_dir" || exit 1
		git init -q
		git config user.email a@b.c
		git config user.name t
		git add . >/dev/null
		git commit -qm init
	)

	run_make "$fixture_dir" ALMKFS_ENV_FILE=.env.custom help >/dev/null 2>&1
	assert_file_exists "$fixture_dir/.env.custom"

	output="$(run_make "$fixture_dir" ALMKFS_ENV_FILE=.env.custom git.clean 2>&1)"

	assert_file_exists "$fixture_dir/.env.custom"
	assert_not_contains "$output" "Removing .env.custom"
}

test_compose_exec_targets_are_generated_from_discovered_services() {
	local fixture_dir
	local database

	eval "$(setup_fixture fixture_dir)"

	write_compose_stub "$fixture_dir"

	cat >"$fixture_dir/compose.yaml" <<'EOF'
services:
  api:
    image: example/api
  worker:
    image: example/worker
EOF

	cat >"$fixture_dir/.env" <<'EOF'
COMPOSE_PROJECT_NAME=test
EOF

	database="$(run_make "$fixture_dir" -pnRr help)"

	assert_contains "$database" "compose.exec-api: compose.ensure-tools"
	assert_contains "$database" "compose.exec-worker: compose.ensure-tools"
}

test_compose_exec_targets_are_skipped_when_service_discovery_fails() {
	local fixture_dir
	local database

	eval "$(setup_fixture fixture_dir)"

	write_compose_stub "$fixture_dir"

	cat >"$fixture_dir/compose.yaml" <<'EOF'
services:
  api:
    image: example/api
EOF

	cat >"$fixture_dir/.env" <<'EOF'
COMPOSE_PROJECT_NAME=test
EOF

	database="$(
		FAKE_DOCKER_COMPOSE_MODE=fail run_make "$fixture_dir" -pnRr help
	)"

	assert_contains "$database" "compose.config: compose.ensure-tools"
	assert_not_contains "$database" "compose.exec-api: compose.ensure-tools"
}

test_help_lists_generated_targets_from_active_modules() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	write_compose_stub "$fixture_dir"

	cat >"$fixture_dir/compose.yaml" <<'EOF'
services:
  api:
    image: example/api
  worker:
    image: example/worker
EOF

	cat >"$fixture_dir/.env" <<'EOF'
COMPOSE_PROJECT_NAME=test
EOF

	output="$(run_make "$fixture_dir" help 2>&1)"

	assert_contains "$output" "compose.exec-api"
	assert_contains "$output" "compose.exec-worker"
}

test_help_accepts_gnu_make_override_names_that_are_invalid_shell_identifiers() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	output="$(
		run_make "$fixture_dir" 'FOO.BAR=override dot' help 2>&1
	)"

	assert_file_exists "$fixture_dir/almakefiles/.env.mk"
	assert_file_exists "$fixture_dir/.env"
	assert_contains "$output" "help"
	assert_contains "$output" "git.clean"
}

test_help_bootstraps_when_project_path_contains_spaces() {
	local fixture_dir
	local output

	eval "$(setup_fixture_with_project_dir_name fixture_dir 'project with space')"

	cat >"$fixture_dir/makefile" <<'EOF'
PROJECT_VAR ?= project-default
include almakefiles/include.mk
EOF

	output="$(run_make "$fixture_dir" help 2>&1)"

	assert_file_exists "$fixture_dir/almakefiles/.env.mk"
	assert_file_exists "$fixture_dir/.env"
	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "PROJECT_VAR = project-default"
	assert_contains "$output" "help"
	assert_contains "$output" "git.clean"
}

test_new_module_files_are_auto_discovered_from_mk_directory() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	write_auto_module_fixture "$fixture_dir"

	output="$(run_make "$fixture_dir" ALMKFS_NO_AUTO_ENV_INIT=1 help 2>&1)"

	assert_contains "$output" "feature.toggle"

	output="$(
		run_make "$fixture_dir" \
			ALMKFS_NO_AUTO_ENV_INIT=1 \
			ALMKFS_DISABLE_MODULE_FEATURE_TOGGLE=1 \
			help 2>&1
	)"

	assert_not_contains "$output" "feature.toggle"
}

test_help_excludes_disabled_module_targets_via_include_entrypoint() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	output="$(
		run_make "$fixture_dir" \
			ALMKFS_NO_AUTO_ENV_INIT=1 \
			ALMKFS_DISABLE_MODULE_DOCKER_COMPOSE=1 \
			ALMKFS_DISABLE_MODULE_GIT=1 \
			help 2>&1
	)"

	assert_contains "$output" "help"
	assert_contains "$output" "env.sync-env.mk"
	assert_not_contains "$output" "compose.config"
	assert_not_contains "$output" "git.clean"
}

test_help_excludes_disabled_module_targets_when_modules_are_included_directly() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/makefile" <<'EOF'
include almakefiles/mk/common.mk
-include almakefiles/mk/docker-compose.mk
-include almakefiles/mk/env.mk
-include almakefiles/mk/git.mk
EOF

	output="$(
		run_make "$fixture_dir" \
			ALMKFS_NO_AUTO_ENV_INIT=1 \
			ALMKFS_DISABLE_MODULE_DOCKER_COMPOSE=1 \
			ALMKFS_DISABLE_MODULE_GIT=1 \
			help 2>&1
	)"

	assert_contains "$output" "help"
	assert_contains "$output" "env.sync-env.mk"
	assert_not_contains "$output" "compose.config"
	assert_not_contains "$output" "git.clean"
}

test_include_entrypoint_rejects_conflicting_dropin_paths() {
	local fixture_dir
	local output
	local status

	eval "$(setup_fixture fixture_dir)"

	cp -R "$fixture_dir/almakefiles" "$fixture_dir/alt-layer"

	cat >"$fixture_dir/makefile" <<'EOF'
include almakefiles/include.mk
include alt-layer/include.mk
EOF

	set +e
	output="$(run_make "$fixture_dir" help 2>&1)"
	status=$?
	set -e

	assert_nonzero_exit "$status" "conflicting include entrypoint exit status"
	assert_contains "$output" "Conflicting almakefiles entrypoints"
	assert_contains "$output" "almakefiles/include.mk"
	assert_contains "$output" "alt-layer/include.mk"
}

run_system_suite() {
	test_almakefiles_recipes_do_not_use_raw_make
	test_almakefiles_make_defines_use_kebab_case
	test_runtime_layout_contains_expected_paths
	test_test_runner_uses_split_suites
	test_git_clean_preserves_custom_env_make_file
	test_compose_exec_targets_are_generated_from_discovered_services
	test_compose_exec_targets_are_skipped_when_service_discovery_fails
	test_help_lists_generated_targets_from_active_modules
	test_help_accepts_gnu_make_override_names_that_are_invalid_shell_identifiers
	test_help_bootstraps_when_project_path_contains_spaces
	test_new_module_files_are_auto_discovered_from_mk_directory
	test_help_excludes_disabled_module_targets_via_include_entrypoint
	test_help_excludes_disabled_module_targets_when_modules_are_included_directly
	test_include_entrypoint_rejects_conflicting_dropin_paths
}
