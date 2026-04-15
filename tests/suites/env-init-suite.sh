#!/usr/bin/env bash

test_first_make_bootstraps_env_make_and_continues() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/project.mk" <<'EOF'
PROJECT_VAR ?= project-default
EOF

	output="$(run_make "$fixture_dir" help 2>&1)"

	assert_file_exists "$fixture_dir/almakefiles/.env.mk"
	assert_file_exists "$fixture_dir/.env"
	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "ALMKFS_ENV_COMPOSE_FILES_CSV = .env"
	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "ALMKFS_ENV_EXAMPLE_PROVENANCE_WARN_ONLY_CSV = "
	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "ALMKFS_DOCKER_COMPOSE_FILES_CSV = compose.yaml"
	assert_file_contains "$fixture_dir/almakefiles/.env.mk" "PROJECT_VAR = project-default"
	assert_contains "$output" "Created almakefiles/.env.mk"
	assert_contains "$output" "compose.config"
	assert_contains "$output" "git.clean"
}

test_nested_in_project_dropin_uses_canonical_directory_path_and_local_env_file() {
	local fixture_dir
	local output

	eval "$(setup_fixture_with_dropin_path fixture_dir "tools/dev-layer" "include ././tools/../tools/dev-layer/include.mk")"

	output="$(run_make "$fixture_dir" help 2>&1)"

	assert_file_exists "$fixture_dir/tools/dev-layer/.env.mk"
	assert_file_not_exists "$fixture_dir/.env.mk"
	assert_file_exists "$fixture_dir/.env"
	assert_contains "$output" "Created tools/dev-layer/.env.mk"
}

test_outside_project_dropin_uses_root_env_make_file() {
	local fixture_dir
	local output

	eval "$(setup_fixture_with_dropin_path fixture_dir "../shared/dev-layer" "include ././../shared/./dev-layer/include.mk")"

	output="$(run_make "$fixture_dir" help 2>&1)"

	assert_file_exists "$fixture_dir/.env.mk"
	assert_file_not_exists "$fixture_dir/../shared/dev-layer/.env.mk"
	assert_file_exists "$fixture_dir/.env"
	assert_contains "$output" "Created .env.mk"
}

test_second_make_help_runs_without_recreating_env_make() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	bootstrap_env_make "$fixture_dir"

	output="$(run_make "$fixture_dir" help 2>&1)"

	assert_file_exists "$fixture_dir/.env"
	assert_contains "$output" "compose.config"
	assert_contains "$output" "git.clean"
	assert_not_contains "$output" "Created almakefiles/.env.mk"
}

test_first_help_with_declared_runtime_env_creates_regular_env_files() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/.env.runtime.example" <<'EOF'
# this file created from .env.runtime.example
RUNTIME_ENV=1
EOF

	output="$(
		run_make "$fixture_dir" ALMKFS_ENV_COMPOSE_FILES_CSV=.env.runtime help 2>&1
	)"

	assert_file_exists "$fixture_dir/almakefiles/.env.mk"
	assert_file_exists "$fixture_dir/.env"
	assert_file_exists "$fixture_dir/.env.runtime"
	assert_contains "$output" "Created almakefiles/.env.mk"
	assert_contains "$output" "compose.config"
}

test_warn_undefined_variables_does_not_disable_bootstrap_or_auto_init() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	output="$(run_make "$fixture_dir" --warn-undefined-variables help 2>&1)"

	assert_file_exists "$fixture_dir/almakefiles/.env.mk"
	assert_file_exists "$fixture_dir/.env"
	assert_contains "$output" "Created almakefiles/.env.mk"
	assert_contains "$output" "Created .env from .env.example"
	assert_contains "$output" "compose.config"
}

test_explicit_env_target_registry_adds_reinit_target_before_file_exists() {
	local fixture_dir
	local database

	eval "$(setup_fixture fixture_dir)"

	rm -f "$fixture_dir/.env.example"
	cat >"$fixture_dir/.env.runtime.example" <<'EOF'
# this file created from .env.runtime.example
RUNTIME_ENV=1
EOF
	cat >"$fixture_dir/.env.alt.example" <<'EOF'
# this file created from .env.alt.example
ALT_ENV=1
EOF

	database="$(
		run_make "$fixture_dir" \
			ALMKFS_NO_AUTO_ENV_INIT=1 \
			ALMKFS_ENV_TARGET_FILE_VARIABLES=RUNTIME_TARGET \
			RUNTIME_TARGET=.env.runtime \
			ALMKFS_ENV_TARGET_FILES_CSV_VARIABLES=RUNTIME_TARGETS \
			RUNTIME_TARGETS=.env.alt \
			-pnRr help 2>&1
	)"

	assert_contains "$database" "env.reinit-env.runtime"
	assert_contains "$database" "env.reinit-env.alt"
}

test_help_lists_generated_reinit_targets() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	output="$(run_make "$fixture_dir" help 2>&1)"

	if ! printf '%s\n' "$output" | rg -q '^env\.reinit-env[[:space:]]'; then
		printf 'Expected help output to list env.reinit-env as a dedicated target.\nActual output:\n%s\n' "$output" >&2
		exit 1
	fi

	cat >"$fixture_dir/.env.runtime.example" <<'EOF'
# this file created from .env.runtime.example
RUNTIME_ENV=1
EOF

	output="$(
		run_make "$fixture_dir" ALMKFS_ENV_COMPOSE_FILES_CSV=.env.runtime help 2>&1
	)"

	if ! printf '%s\n' "$output" | rg -q '^env\.reinit-env\.runtime[[:space:]]'; then
		printf 'Expected help output to list env.reinit-env.runtime as a dedicated target.\nActual output:\n%s\n' "$output" >&2
		exit 1
	fi
}

test_help_renders_generated_reinit_target_descriptions_with_real_file_names() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	output="$(run_make "$fixture_dir" help 2>&1)"

	if ! printf '%s\n' "$output" | rg -q '^env\.reinit-env[[:space:]]+Reinitialize the matching \.env file from \.env\.example$'; then
		printf 'Expected help output to render the env.reinit-env description with concrete file names.\nActual output:\n%s\n' "$output" >&2
		exit 1
	fi

	cat >"$fixture_dir/.env.runtime.example" <<'EOF'
# this file created from .env.runtime.example
RUNTIME_ENV=1
EOF

	output="$(
		run_make "$fixture_dir" ALMKFS_ENV_COMPOSE_FILES_CSV=.env.runtime help 2>&1
	)"

	if ! printf '%s\n' "$output" | rg -q '^env\.reinit-env\.runtime[[:space:]]+Reinitialize the matching \.env\.runtime file from \.env\.runtime\.example$'; then
		printf 'Expected help output to render the env.reinit-env.runtime description with concrete file names.\nActual output:\n%s\n' "$output" >&2
		exit 1
	fi
}

test_dry_run_long_option_does_not_bootstrap_or_auto_init() {
	local fixture_dir

	eval "$(setup_fixture fixture_dir)"

	run_make "$fixture_dir" --dry-run help >/dev/null 2>&1

	assert_file_not_exists "$fixture_dir/almakefiles/.env.mk"
	assert_file_not_exists "$fixture_dir/.env"
}

test_non_query_makeflags_with_output_sync_argument_does_not_disable_bootstrap_or_auto_init() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/makefile" <<'EOF'
MAKEFLAGS += -Onone
include almakefiles/include.mk
EOF

	output="$(run_make "$fixture_dir" help 2>&1)"

	assert_file_exists "$fixture_dir/almakefiles/.env.mk"
	assert_file_exists "$fixture_dir/.env"
	assert_contains "$output" "Created almakefiles/.env.mk"
	assert_contains "$output" "Created .env from .env.example"
}

test_non_query_makeflags_with_include_dir_argument_does_not_disable_bootstrap_or_auto_init() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/makefile" <<'EOF'
MAKEFLAGS += -I nope
include almakefiles/include.mk
EOF

	output="$(run_make "$fixture_dir" help 2>&1)"

	assert_file_exists "$fixture_dir/almakefiles/.env.mk"
	assert_file_exists "$fixture_dir/.env"
	assert_contains "$output" "Created almakefiles/.env.mk"
	assert_contains "$output" "Created .env from .env.example"
}

test_missing_example_provenance_is_auto_added_on_normal_make() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/.env.example" <<'EOF'
ROOT_ENV=1
EOF

	output="$(run_make "$fixture_dir" help 2>&1)"

	assert_contains "$output" "Info: Added provenance header to .env.example"
	assert_first_line_equals "$fixture_dir/.env.example" "# this file created from .env.example"
	assert_first_line_equals "$fixture_dir/.env" "# this file created from .env.example"
	assert_line_count "$fixture_dir/.env.example" "# this file created from .env.example" 1
	assert_line_count "$fixture_dir/.env" "# this file created from .env.example" 1
}

test_invalid_example_provenance_is_rewritten_in_place() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/.env.example" <<'EOF'
# this file created from .env.wrong.example
ROOT_ENV=1
EOF

	output="$(run_make "$fixture_dir" help 2>&1)"

	assert_contains "$output" "Info: Rewrote invalid provenance header in .env.example"
	assert_first_line_equals "$fixture_dir/.env.example" "# this file created from .env.example"
	assert_first_line_equals "$fixture_dir/.env" "# this file created from .env.example"
	assert_line_count "$fixture_dir/.env.example" "# this file created from .env.example" 1
	assert_file_not_contains "$fixture_dir/.env.example" ".env.wrong.example"
}

test_valid_example_provenance_is_left_untouched() {
	local fixture_dir
	local output
	local before_sha
	local after_sha

	eval "$(setup_fixture fixture_dir)"

	before_sha="$(file_sha256 "$fixture_dir/.env.example")"
	output="$(run_make "$fixture_dir" help 2>&1)"
	after_sha="$(file_sha256 "$fixture_dir/.env.example")"

	assert_equals "$after_sha" "$before_sha" ".env.example sha256"
	assert_not_contains "$output" "Info: Added provenance header to .env.example"
	assert_not_contains "$output" "Info: Rewrote invalid provenance header in .env.example"
}

test_exempt_example_provenance_warns_without_rewrite() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/.env.runtime.example" <<'EOF'
RUNTIME_ENV=1
EOF

	output="$(
		run_make "$fixture_dir" ALMKFS_ENV_EXAMPLE_PROVENANCE_WARN_ONLY_CSV=./.env.runtime.example help 2>&1
	)"

	assert_contains "$output" "Warning: .env.runtime.example is missing a valid provenance header and is exempt from auto-fix"
	assert_first_line_equals "$fixture_dir/.env.runtime.example" "RUNTIME_ENV=1"
	assert_file_exists "$fixture_dir/.env.runtime"
	assert_first_line_equals "$fixture_dir/.env.runtime" "RUNTIME_ENV=1"
}

test_single_target_resolution_requires_matching_example_after_provenance_prepass() {
	local fixture_dir
	local output
	local status

	eval "$(setup_fixture fixture_dir)"

	rm -f "$fixture_dir/.env.example"
	cat >"$fixture_dir/.env.base.example" <<'EOF'
BASE_ENV=1
EOF

	set +e
	output="$(
			run_make "$fixture_dir" ALMKFS_ENV_COMPOSE_FILES_CSV=.env.runtime help 2>&1
	)"
	status=$?
	set -e

	assert_nonzero_exit "$status" "help without matching example after provenance prepass"
	assert_contains "$output" "Info: Added provenance header to .env.base.example"
	assert_contains "$output" "Unable to resolve env targets: .env.runtime"
	assert_contains "$output" "Available env examples: .env.base.example"
	assert_first_line_equals "$fixture_dir/.env.base.example" "# this file created from .env.base.example"
	assert_file_not_exists "$fixture_dir/.env.runtime"
}

test_multiple_example_resolution_still_behaves_after_provenance_prepass() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/.env.runtime.example" <<'EOF'
RUNTIME_ENV=1
EOF

	cat >"$fixture_dir/.env.alpha.example" <<'EOF'
# this file created from .env.alpha.wrong.example
ALPHA_ENV=1
EOF

	output="$(
		run_make "$fixture_dir" ALMKFS_ENV_COMPOSE_FILES_CSV=.env.runtime help 2>&1
	)"

	assert_contains "$output" "Info: Added provenance header to .env.runtime.example"
	assert_contains "$output" "Info: Rewrote invalid provenance header in .env.alpha.example"
	assert_file_exists "$fixture_dir/.env"
	assert_file_exists "$fixture_dir/.env.runtime"
	assert_file_exists "$fixture_dir/.env.alpha"
	assert_first_line_equals "$fixture_dir/.env.runtime" "# this file created from .env.runtime.example"
	assert_file_contains "$fixture_dir/.env.runtime" "RUNTIME_ENV=1"
	assert_first_line_equals "$fixture_dir/.env.alpha" "# this file created from .env.alpha.example"
	assert_file_contains "$fixture_dir/.env.alpha" "ALPHA_ENV=1"
}

test_env_reinit_enforces_example_provenance_before_copying() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	bootstrap_env_make "$fixture_dir"

	cat >"$fixture_dir/.env.runtime.example" <<'EOF'
# this file created from .env.wrong.example
RUNTIME_ENV=1
EOF

	cat >"$fixture_dir/.env.runtime" <<'EOF'
OLD_RUNTIME_ENV=1
EOF

	output="$(
		run_make "$fixture_dir" ALMKFS_ENV_COMPOSE_FILES_CSV=.env.runtime env.reinit-env.runtime 2>&1
	)"

	assert_contains "$output" "Info: Rewrote invalid provenance header in .env.runtime.example"
	assert_contains "$output" "Reinitialized .env.runtime from .env.runtime.example"
	assert_first_line_equals "$fixture_dir/.env.runtime.example" "# this file created from .env.runtime.example"
	assert_first_line_equals "$fixture_dir/.env.runtime" "# this file created from .env.runtime.example"
	assert_file_contains "$fixture_dir/.env.runtime" "RUNTIME_ENV=1"
	assert_file_not_contains "$fixture_dir/.env.runtime" "OLD_RUNTIME_ENV=1"
}

test_query_mode_does_not_mutate_examples_or_targets_when_example_provenance_is_invalid() {
	local fixture_dir
	local output
	local before_sha
	local after_sha

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/.env.example" <<'EOF'
ROOT_ENV=1
EOF

	before_sha="$(file_sha256 "$fixture_dir/.env.example")"
	output="$(run_make "$fixture_dir" -pnRr help 2>&1)"
	after_sha="$(file_sha256 "$fixture_dir/.env.example")"

	assert_equals "$after_sha" "$before_sha" ".env.example sha256 in query mode"
	assert_file_not_exists "$fixture_dir/.env"
	assert_not_contains "$output" "Info: Added provenance header to .env.example"
	assert_not_contains "$output" "Info: Rewrote invalid provenance header in .env.example"
}

test_second_help_with_declared_runtime_env_is_idempotent() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/.env.runtime.example" <<'EOF'
# this file created from .env.runtime.example
RUNTIME_ENV=1
EOF

	cat >"$fixture_dir/.env.alpha.example" <<'EOF'
# this file created from .env.alpha.example
ALPHA_ENV=1
EOF

	run_make "$fixture_dir" ALMKFS_ENV_COMPOSE_FILES_CSV=.env.runtime help >/dev/null 2>&1
	output="$(run_make "$fixture_dir" ALMKFS_ENV_COMPOSE_FILES_CSV=.env.runtime help 2>&1)"

	assert_file_exists "$fixture_dir/almakefiles/.env.mk"
	assert_file_exists "$fixture_dir/.env"
	assert_file_exists "$fixture_dir/.env.runtime"
	assert_file_exists "$fixture_dir/.env.alpha"
	assert_first_line_equals "$fixture_dir/.env.runtime" "# this file created from .env.runtime.example"
	assert_not_contains "$output" "Created .env.runtime from .env.runtime.example"
}

test_query_mode_does_not_bootstrap_env_make() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	output="$(run_make "$fixture_dir" -pnRr help 2>&1)"

	assert_file_not_exists "$fixture_dir/almakefiles/.env.mk"
	assert_file_not_exists "$fixture_dir/.env"
	assert_contains "$output" "compose.config: compose.ensure-tools"
}

test_query_mode_with_cli_env_make_override_does_not_create_any_env_files() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	output="$(run_make "$fixture_dir" ALMKFS_ENV_FILE=.env.kek -pnRr help 2>&1)"

	assert_file_not_exists "$fixture_dir/.env.kek"
	assert_file_not_exists "$fixture_dir/.env"
	assert_contains "$output" "compose.config: compose.ensure-tools"
}

test_env_reinit_overwrites_existing_target_from_example() {
	local fixture_dir
	local runtime_file
	local runtime_contents

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/.env.runtime.example" <<'EOF'
# this file created from .env.runtime.example
RUNTIME_ENV=1
EOF

	bootstrap_env_make "$fixture_dir"

	runtime_file="$fixture_dir/.env.runtime"
	cat >"$runtime_file" <<'EOF'
OLD_RUNTIME_ENV=1
EOF

	run_make "$fixture_dir" ALMKFS_ENV_COMPOSE_FILES_CSV=.env.runtime env.reinit-env.runtime

	assert_file_exists "$fixture_dir/.env"
	assert_first_line_equals "$runtime_file" "# this file created from .env.runtime.example"
	runtime_contents="$(cat "$runtime_file")"
	assert_contains "$runtime_contents" "RUNTIME_ENV=1"
	assert_not_contains "$runtime_contents" "OLD_RUNTIME_ENV=1"
}

test_env_reinit_requires_matching_example() {
	local fixture_dir
	local output
	local status

	eval "$(setup_fixture fixture_dir)"

	rm -f "$fixture_dir/.env.example"
	cat >"$fixture_dir/.env.base.example" <<'EOF'
# this file created from .env.base.example
BASE_ENV=1
EOF

	set +e
	output="$(
		run_make "$fixture_dir" ALMKFS_NO_AUTO_ENV_INIT=1 ALMKFS_ENV_COMPOSE_FILES_CSV=.env.runtime env.reinit-env.runtime 2>&1
	)"
	status=$?
	set -e

	assert_nonzero_exit "$status" "env.reinit without matching example"
	assert_contains "$output" "Unable to resolve env targets: .env.runtime"
	assert_file_not_exists "$fixture_dir/.env.runtime"
	assert_file_exists "$fixture_dir/.env.base.example"
}

test_recursive_make_does_not_bootstrap_or_auto_init_env_files() {
	local fixture_dir
	local output

	eval "$(setup_fixture fixture_dir)"

	cat >"$fixture_dir/makefile" <<'EOF'
include almakefiles/include.mk

inner:
	test ! -e almakefiles/.env.mk
	test ! -e .env

outer:
	rm -f almakefiles/.env.mk .env
	$(MAKE) -f makefile inner
EOF

	output="$(run_make "$fixture_dir" outer 2>&1)"

	assert_contains "$output" "Created almakefiles/.env.mk"
	assert_contains "$output" "Created .env from .env.example"
	assert_file_not_exists "$fixture_dir/almakefiles/.env.mk"
	assert_file_not_exists "$fixture_dir/.env"
}

run_env_init_suite() {
	test_first_make_bootstraps_env_make_and_continues
	test_nested_in_project_dropin_uses_canonical_directory_path_and_local_env_file
	test_outside_project_dropin_uses_root_env_make_file
	test_second_make_help_runs_without_recreating_env_make
	test_first_help_with_declared_runtime_env_creates_regular_env_files
	test_missing_example_provenance_is_auto_added_on_normal_make
	test_invalid_example_provenance_is_rewritten_in_place
	test_valid_example_provenance_is_left_untouched
	test_exempt_example_provenance_warns_without_rewrite
	test_warn_undefined_variables_does_not_disable_bootstrap_or_auto_init
	test_single_target_resolution_requires_matching_example_after_provenance_prepass
	test_multiple_example_resolution_still_behaves_after_provenance_prepass
	test_help_lists_generated_reinit_targets
	test_help_renders_generated_reinit_target_descriptions_with_real_file_names
	test_env_reinit_enforces_example_provenance_before_copying
	test_query_mode_does_not_mutate_examples_or_targets_when_example_provenance_is_invalid
	test_dry_run_long_option_does_not_bootstrap_or_auto_init
	test_non_query_makeflags_with_output_sync_argument_does_not_disable_bootstrap_or_auto_init
	test_non_query_makeflags_with_include_dir_argument_does_not_disable_bootstrap_or_auto_init
	test_second_help_with_declared_runtime_env_is_idempotent
	test_query_mode_does_not_bootstrap_env_make
	test_query_mode_with_cli_env_make_override_does_not_create_any_env_files
	test_env_reinit_overwrites_existing_target_from_example
	test_env_reinit_requires_matching_example
	test_recursive_make_does_not_bootstrap_or_auto_init_env_files
}
