#!/usr/bin/env bash

assert_file_exists() {
	local path="$1"

	if [[ ! -f "$path" ]]; then
		printf 'Expected file to exist: %s\n' "$path" >&2
		exit 1
	fi
}

assert_file_not_exists() {
	local path="$1"

	if [[ -e "$path" ]]; then
		printf 'Expected file to be absent: %s\n' "$path" >&2
		exit 1
	fi
}

assert_contains() {
	local haystack="$1"
	local needle="$2"

	if [[ "$haystack" != *"$needle"* ]]; then
		printf 'Expected output to contain: %s\n' "$needle" >&2
		printf 'Actual output:\n%s\n' "$haystack" >&2
		exit 1
	fi
}

assert_not_contains() {
	local haystack="$1"
	local needle="$2"

	if [[ "$haystack" == *"$needle"* ]]; then
		printf 'Expected output not to contain: %s\n' "$needle" >&2
		printf 'Actual output:\n%s\n' "$haystack" >&2
		exit 1
	fi
}

assert_file_contains() {
	local path="$1"
	local needle="$2"
	local content

	content="$(cat "$path")"
	assert_contains "$content" "$needle"
}

assert_file_not_contains() {
	local path="$1"
	local needle="$2"
	local content

	content="$(cat "$path")"
	assert_not_contains "$content" "$needle"
}

assert_first_line_equals() {
	local path="$1"
	local expected="$2"
	local actual

	actual="$(head -n 1 "$path")"
	if [[ "$actual" != "$expected" ]]; then
		printf 'Unexpected first line for %s\nExpected: %s\nActual:   %s\n' "$path" "$expected" "$actual" >&2
		exit 1
	fi
}

assert_equals() {
	local actual="$1"
	local expected="$2"
	local label="${3:-values}"

	if [[ "$actual" != "$expected" ]]; then
		printf 'Unexpected %s\nExpected: %s\nActual:   %s\n' "$label" "$expected" "$actual" >&2
		exit 1
	fi
}

assert_nonzero_exit() {
	local status="$1"
	local label="${2:-command exit status}"

	if [[ "$status" -eq 0 ]]; then
		printf 'Expected non-zero %s\n' "$label" >&2
		exit 1
	fi
}

assert_line_count() {
	local path="$1"
	local needle="$2"
	local expected_count="$3"
	local actual_count

	actual_count="$(grep -cFx "$needle" "$path" || true)"
	assert_equals "$actual_count" "$expected_count" "line count for $needle in $path"
}

file_sha256() {
	local path="$1"

	sha256sum "$path" | awk '{print $1}'
}

create_fixture() {
	create_fixture_with_dropin_path "almakefiles" "include almakefiles/include.mk"
}

create_fixture_with_dropin_path() {
	local dropin_path="$1"
	local include_line="$2"
	local workspace_dir
	local fixture_dir

	workspace_dir="$(mktemp -d)"
	fixture_dir="$workspace_dir/project"
	mkdir -p "$fixture_dir/$dropin_path"
	(
		cd "$REPO_ROOT" || exit 1
		find . -mindepth 1 -maxdepth 1 ! -name '.git' ! -name '.env.mk' -exec cp -R {} "$fixture_dir/$dropin_path/" \;
	)
	printf '%s\n' "$include_line" >"$fixture_dir/makefile"
	cat >"$fixture_dir/.env.example" <<'EOF'
# this file created from .env.example
ROOT_ENV=1
EOF
	mkdir -p "$fixture_dir/bin"

	printf '%s\n' "$fixture_dir"
}

setup_fixture() {
	local variable_name="$1"
	local fixture_path

	fixture_path="$(create_fixture)"
	printf 'trap -- %q RETURN\n' "$(fixture_cleanup_trap_command "$fixture_path")"
	printf '%s=%q\n' "$variable_name" "$fixture_path"
}

setup_fixture_with_dropin_path() {
	local variable_name="$1"
	local dropin_path="$2"
	local include_line="$3"
	local fixture_path

	fixture_path="$(create_fixture_with_dropin_path "$dropin_path" "$include_line")"
	printf 'trap -- %q RETURN\n' "$(fixture_cleanup_trap_command "$fixture_path")"
	printf '%s=%q\n' "$variable_name" "$fixture_path"
}

fixture_cleanup_trap_command() {
	local fixture_dir="$1"

	printf 'rm -rf -- %q' "$(dirname "$fixture_dir")"
}

write_compose_stub() {
	local fixture_dir="$1"

	cat >"$fixture_dir/bin/docker-compose" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "version" ]]; then
	exit 0
fi

if [[ "$*" == *"config --services"* ]]; then
	if [[ "${FAKE_DOCKER_COMPOSE_MODE:-success}" == "fail" ]]; then
		exit 1
	fi

	printf 'api\nworker\n'
	exit 0
fi

printf 'unexpected docker-compose invocation: %s\n' "$*" >&2
exit 1
EOF

	chmod +x "$fixture_dir/bin/docker-compose"
}

write_auto_module_fixture() {
	local fixture_dir="$1"

cat >"$fixture_dir/almakefiles/mk/feature-toggle.mk" <<'EOF'
ifeq ($(ALMKFS_DISABLE_MODULE_FEATURE_TOGGLE),1)
else ifndef __ALMKFS_INCLUDE_GUARD_FEATURE_TOGGLE
override __ALMKFS_INCLUDE_GUARD_FEATURE_TOGGLE = 1
ALMKFS_DISABLE_MODULE_FEATURE_TOGGLE ?=

ALMKFS_FEATURE_TOGGLE_VALUE ?= feature-toggle-default

feature.toggle: ## Toggle feature target
	@printf '%s\n' 'feature-toggle'

endif
EOF
}

run_make() {
	local fixture_dir="$1"
	shift

	(
		cd "$fixture_dir" || exit 1
		PATH="$fixture_dir/bin:$PATH" make -f makefile "$@"
	)
}

bootstrap_env_make() {
	local fixture_dir="$1"

	run_make "$fixture_dir" help >/dev/null 2>&1
}
