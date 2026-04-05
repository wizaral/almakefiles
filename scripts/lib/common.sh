#!/usr/bin/env bash

if [[ -n "${ALMAKE_SCRIPT_COMMON_SH_LOADED:-}" ]]; then
	return 0
fi
ALMAKE_SCRIPT_COMMON_SH_LOADED=1

# Shared helpers used by multiple internal shell scripts.

trim_whitespace() {
	local value="$1"

	value="${value#"${value%%[![:space:]]*}"}"
	value="${value%"${value##*[![:space:]]}"}"

	printf '%s' "$value"
}

append_unique() {
	local list_name="$1"
	local -n append_unique_list="$list_name"
	local value="$2"
	local item

	for item in "${append_unique_list[@]}"; do
		if [[ "$item" == "$value" ]]; then
			return 0
		fi
	done

	append_unique_list+=("$value")
}

contains_item() {
	local list_name="$1"
	local -n contains_item_list="$list_name"
	local value="$2"
	local item

	for item in "${contains_item_list[@]}"; do
		if [[ "$item" == "$value" ]]; then
			return 0
		fi
	done

	return 1
}

remove_item() {
	local list_name="$1"
	local -n remove_item_list="$list_name"
	local value="$2"
	local filtered=()
	local item

	for item in "${remove_item_list[@]}"; do
		if [[ "$item" != "$value" ]]; then
			filtered+=("$item")
		fi
	done

	remove_item_list=("${filtered[@]}")
}

split_csv() {
	local csv="$1"
	local raw_items=()
	local item

	if [[ -z "$csv" ]]; then
		return 0
	fi

	IFS=',' read -r -a raw_items <<<"$csv"
	for item in "${raw_items[@]}"; do
		item="$(trim_whitespace "$item")"
		if [[ -n "$item" ]]; then
			printf '%s\n' "$item"
		fi
	done
}

write_file_atomic() {
	local target_path="$1"
	local reference_path="${2:-}"
	local target_dir
	local temp_file
	local current_umask
	local mode

	target_dir="$(dirname -- "$target_path")"
	mkdir -p "$target_dir"

	temp_file="$(mktemp "$target_dir/.write-file-atomic.XXXXXX")"
	trap 'rm -f "$temp_file"' RETURN

	cat >"$temp_file"

	if [[ -n "$reference_path" && -e "$reference_path" ]]; then
		chmod --reference="$reference_path" "$temp_file"
	else
		current_umask="$(umask)"
		mode=$(( 8#666 & (8#777 ^ 8#$current_umask) ))
		printf -v mode '%03o' "$mode"
		chmod "$mode" "$temp_file"
	fi

	mv "$temp_file" "$target_path"
	trap - RETURN
}
