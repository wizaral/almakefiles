#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "${script_dir}/lib/common.sh"

declare -a declared_targets=()
declare -a unresolved_targets=()
declare -a all_examples=()
declare -a used_examples=()
declare -a remaining_examples=()
declare -a warn_only_examples=()
force_reinit=0
fix_example_provenance=0

# Referenced directly to keep shellcheck aware; mutations mostly happen via namerefs.
: "${used_examples[*]-}" "${warn_only_examples[*]-}"
normalize_example_name() {
	local value="$1"

	value="$(trim_whitespace "$value")"
	while [[ "$value" == ./* ]]; do
		value="${value#./}"
	done

	printf '%s' "$value"
}

load_warn_only_examples() {
	local item
	local normalized

	warn_only_examples=()
	while IFS= read -r item; do
		normalized="$(normalize_example_name "$item")"
		if [[ -n "$normalized" ]]; then
			append_unique warn_only_examples "$normalized"
		fi
	done < <(split_csv "${ALMKFS_ENV_EXAMPLE_PROVENANCE_WARN_ONLY_CSV:-}")
}

read_first_line() {
	local path="$1"
	local line=""

	if IFS= read -r line <"$path" || [[ -n "$line" ]]; then
		printf '%s' "$line"
	fi
}

replace_first_line() {
	local path="$1"
	local first_line="$2"

	{
		printf '%s\n' "$first_line"
		tail -n +2 -- "$path"
	} | write_file_atomic "$path" "$path"
}

prepend_first_line() {
	local path="$1"
	local first_line="$2"

	{
		printf '%s\n' "$first_line"
		cat "$path"
	} | write_file_atomic "$path" "$path"
}

expected_provenance_header() {
	local example="$1"

	printf '# this file created from %s' "$example"
}

example_has_valid_provenance() {
	local example="$1"
	local first_line
	local expected_header

	expected_header="$(expected_provenance_header "$example")"
	first_line="$(read_first_line "$example")"
	[[ "$first_line" == "$expected_header" ]]
}

warn_invalid_example_provenance() {
	local example="$1"

	printf 'Warning: %s is missing a valid provenance header and normal runs do not rewrite source examples\n' "$example" >&2
}

fix_example_provenance_in_place() {
	local example
	local expected_header
	local first_line

	load_warn_only_examples
	for example in "${all_examples[@]}"; do
		expected_header="$(expected_provenance_header "$example")"
		first_line="$(read_first_line "$example")"

		if [[ "$first_line" == "$expected_header" ]]; then
			continue
		fi

		if contains_item warn_only_examples "$example"; then
			printf 'Warning: %s is missing a valid provenance header and is exempt from explicit fix\n' "$example" >&2
			continue
		fi

		if [[ "$first_line" == '# this file created from '* ]]; then
			replace_first_line "$example" "$expected_header"
			printf 'Info: Rewrote invalid provenance header in %s\n' "$example"
		else
			prepend_first_line "$example" "$expected_header"
			printf 'Info: Added provenance header to %s\n' "$example"
		fi
	done
}

copy_example_to_target() {
	local target="$1"
	local example="$2"
	local expected_header
	local first_line
	local reference_path=""

	expected_header="$(expected_provenance_header "$example")"
	first_line="$(read_first_line "$example")"

	if [[ -f "$target" ]]; then
		reference_path="$target"
	fi

	{
		printf '%s\n' "$expected_header"
		if [[ "$first_line" == '# this file created from '* ]]; then
			tail -n +2 -- "$example"
		else
			cat "$example"
		fi
	} | write_file_atomic "$target" "$reference_path"
}

validate_example_provenance_prepass() {
	local example

	for example in "${all_examples[@]}"; do
		if ! example_has_valid_provenance "$example"; then
			warn_invalid_example_provenance "$example"
		fi
	done
}

copy_if_missing() {
	local target="$1"
	local example="$2"

	if [[ "$force_reinit" -eq 1 && -f "$target" ]]; then
		copy_example_to_target "$target" "$example"
		printf 'Reinitialized %s from %s\n' "$target" "$example"
	elif [[ ! -f "$target" ]]; then
		copy_example_to_target "$target" "$example"
		printf 'Created %s from %s\n' "$target" "$example"
	else
		printf '%s already exists\n' "$target"
	fi
}

read_provenance_example() {
	local target="$1"
	local source_example

	source_example="$(sed -n '1s/^# this file created from //p' "$target")"
	if [[ -n "$source_example" && "$source_example" =~ ^\.env[^[:space:]]*\.example$ && -f "$source_example" ]]; then
		printf '%s\n' "$source_example"
		return 0
	fi

	return 1
}

collect_remaining_examples() {
	local example

	remaining_examples=()
	for example in "${all_examples[@]}"; do
		if ! contains_item used_examples "$example"; then
			remaining_examples+=("$example")
		fi
	done
}

collect_declared_targets() {
	local target

	declared_targets=()
	for target in "$@"; do
		if [[ -n "$target" ]]; then
			append_unique declared_targets "$target"
		fi
	done

	unresolved_targets=("${declared_targets[@]}")
}

discover_examples() {
	all_examples=()
	if mapfile -t all_examples < <(find . -maxdepth 1 -type f -name '.env*.example' -printf '%f\n' | LC_ALL=C sort -u); then
		:
	fi
}

resolve_existing_declared_targets() {
	local target
	local source_example

	if [[ "$force_reinit" -eq 1 ]]; then
		return 0
	fi

	for target in "${declared_targets[@]}"; do
		if [[ -f "$target" ]]; then
			remove_item unresolved_targets "$target"
			if source_example="$(read_provenance_example "$target")"; then
				append_unique used_examples "$source_example"
			else
				printf 'Warning: %s is missing a valid provenance header\n' "$target" >&2
			fi
		fi
	done
}

resolve_declared_targets_from_matching_examples() {
	local target
	local example

	for target in "${unresolved_targets[@]}"; do
		example="${target}.example"
		if [[ -f "$example" ]]; then
			copy_if_missing "$target" "$example"
			remove_item unresolved_targets "$target"
			append_unique used_examples "$example"
		fi
	done
}

fail_on_unresolved_targets() {
	if [[ "${#unresolved_targets[@]}" -eq 0 ]]; then
		return 0
	fi

	collect_remaining_examples
	printf 'Unable to resolve env targets: %s\n' "${unresolved_targets[*]}" >&2
	printf 'Available env examples: %s\n' "${remaining_examples[*]}" >&2
	exit 1
}

create_remaining_targets_from_unused_examples() {
	local example
	local target

	if [[ "$force_reinit" -eq 1 ]]; then
		return 0
	fi

	collect_remaining_examples

	for example in "${remaining_examples[@]}"; do
		target="${example%.example}"
		if [[ ! -f "$target" ]]; then
			copy_if_missing "$target" "$example"
		fi
	done
}

main() {
	if [[ "${1:-}" == "--force" ]]; then
		force_reinit=1
		shift
	fi

	if [[ "${1:-}" == "--fix-examples" ]]; then
		fix_example_provenance=1
		shift
	fi

	discover_examples

	if [[ "$fix_example_provenance" -eq 1 ]]; then
		fix_example_provenance_in_place
		return 0
	fi

	collect_declared_targets "$@"
	validate_example_provenance_prepass
	resolve_existing_declared_targets
	resolve_declared_targets_from_matching_examples
	fail_on_unresolved_targets
	create_remaining_targets_from_unused_examples
}

main "$@"
