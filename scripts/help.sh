#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "${script_dir}/lib/common.sh"

make_bin="${ALMKFS_MAKE_BIN:-make}"
help_target="${HELP_TARGET:-help}"

declare -a active_targets=()
declare -a help_files=()
declare -a help_patterns=()
declare -a help_descriptions=()
declare -a pattern_placeholders=()
declare -a command_line_override_args=()

declare -A active_target_set=()
declare -A printed_targets=()

database_file=""
parsed_target_spec=""
parsed_help_description=""

cleanup() {
	if [[ -n "$database_file" && -e "$database_file" ]]; then
		rm -f "$database_file"
	fi
}

trap cleanup EXIT

load_make_database() {
	local var_name
	local -a make_command=()

	database_file="$(mktemp)"
	command_line_override_args=()
	while IFS= read -r var_name; do
		if [[ -z "$var_name" ]]; then
			continue
		fi

		command_line_override_args+=("${var_name}=${!var_name-}")
	done < <(printf '%s\n' "${__ALMKFS_COMMAND_LINE_VARIABLES:-}" | tr ' ' '\n')

	make_command=("$make_bin" "${command_line_override_args[@]}" -pnRr "$help_target")
	"${make_command[@]}" >"$database_file" 2>/dev/null
}

load_active_targets() {
	local target

	while IFS= read -r target; do
		append_unique active_targets "$target"
		active_target_set["$target"]=1
	done < <(
		awk '
			/^# Files$/ {
				in_files = 1
				next
			}

			in_files && /^# files hash-table stats:/ {
				exit
			}

			in_files && /^# Not a target:/ {
				not_target = 1
				next
			}

			in_files && /^[^#[:space:]][^:]*:/ {
				line = $0
				sub(/:.*/, "", line)
				if (!not_target) {
					print line
				}
				not_target = 0
				next
			}

			in_files && /^$/ {
				not_target = 0
			}
		' "$database_file"
	)
}

load_help_files_from_csv() {
	local path

	while IFS= read -r path; do
		if [[ -f "$path" ]]; then
			append_unique help_files "$path"
		fi
	done < <(split_csv "${__ALMKFS_HELP_FILE_LIST_CSV:-}")
}

load_help_files_from_database() {
	local path
	local raw_makefile_list=""
	local -a makefile_words=()

	raw_makefile_list="$(awk '
		/^MAKEFILE_LIST := / {
			sub(/^MAKEFILE_LIST := /, "")
			print
			exit
		}
	' "$database_file")"

	read -r -a makefile_words <<<"$raw_makefile_list"
	for path in "${makefile_words[@]}"; do
		if [[ -f "$path" ]]; then
			append_unique help_files "$path"
		fi
	done
}

load_help_files() {
	load_help_files_from_csv

	if ((${#help_files[@]} == 0)); then
		load_help_files_from_database
	fi
}

parse_help_declaration() {
	local line="$1"
	local char=""
	local next_char=""
	local colon_index=-1
	local comment_index=-1
	local depth=0
	local index

	parsed_target_spec=""
	parsed_help_description=""

	if [[ "$line" =~ ^[[:space:]]*$ || "$line" == [[:space:]]* || "$line" == \#* ]]; then
		return 1
	fi

	for ((index = 0; index < ${#line}; index += 1)); do
		char="${line:index:1}"
		next_char="${line:index+1:1}"

		if [[ "$char" == '$' && "$next_char" == '(' ]]; then
			depth=$((depth + 1))
			index=$((index + 1))
			continue
		fi

		if ((depth > 0)) && [[ "$char" == ')' ]]; then
			depth=$((depth - 1))
			continue
		fi

		if ((depth == 0 && colon_index < 0)) && [[ "$char" == ':' ]]; then
			colon_index=$index
			continue
		fi

		if ((depth == 0 && colon_index >= 0)) && [[ "$char" == '#' && "$next_char" == '#' ]]; then
			comment_index=$index
			break
		fi
	done

	if ((colon_index < 0 || comment_index < 0)); then
		return 1
	fi

	parsed_target_spec="$(trim_whitespace "${line:0:colon_index}")"
	parsed_help_description="$(trim_whitespace "${line:comment_index+2}")"

	[[ -n "$parsed_target_spec" && -n "$parsed_help_description" ]]
}

load_help_declarations() {
	local file
	local line
	local description
	local target_spec
	local target
	local -a targets=()

	for file in "${help_files[@]}"; do
		while IFS= read -r line || [[ -n "$line" ]]; do
			if parse_help_declaration "$line"; then
				target_spec="$parsed_target_spec"
				description="$parsed_help_description"
				read -r -a targets <<<"$target_spec"
				for target in "${targets[@]}"; do
					help_patterns+=("$target")
					help_descriptions+=("$description")
				done
			fi
		done <"$file"
	done
}

escape_ere_char() {
	local char="$1"

	case "$char" in
		"\\" | '.' | '^' | '$' | '|' | '(' | ')' | '[' | ']' | '*' | '+' | '?' | '{' | '}')
			printf '\\%s' "$char"
			;;
		*)
			printf '%s' "$char"
			;;
	esac
}

extract_placeholder_token() {
	local text="$1"
	local start="$2"
	local i

	if [[ ! "${text:start+2:1}" =~ [0-9] ]]; then
		return 1
	fi

	for ((i = start + 2; i < ${#text}; i += 1)); do
		if [[ "${text:i:1}" == ')' ]]; then
			printf '%s' "${text:start:i-start+1}"
			return 0
		fi
	done

	return 1
}

extract_placeholder_argument_index() {
	local token="$1"

	if [[ "$token" =~ ^\$([0-9]+)$ ]]; then
		printf '%s' "${BASH_REMATCH[1]}"
		return 0
	fi

	if [[ "$token" =~ ^\$\(([0-9]+)\)$ ]]; then
		printf '%s' "${BASH_REMATCH[1]}"
		return 0
	fi

	if [[ "$token" =~ ^\$\(([0-9]+):\.%=%\)$ ]]; then
		printf '%s' "${BASH_REMATCH[1]}"
		return 0
	fi

	return 1
}

restore_placeholder_argument_value() {
	local token="$1"
	local value="$2"

	if [[ "$token" =~ ^\$\(([0-9]+):\.%=%\)$ ]]; then
		printf '.%s' "$value"
		return 0
	fi

	printf '%s' "$value"
}

build_target_regex() {
	local pattern="$1"
	local index=0
	local token=""
	local char=""
	local next_char=""

	pattern_placeholders=()
	target_regex='^'

	while ((index < ${#pattern})); do
		char="${pattern:index:1}"
		if [[ "$char" == '$' ]]; then
			next_char="${pattern:index+1:1}"
			if [[ "$next_char" =~ [0-9] ]]; then
				token="\$${next_char}"
				pattern_placeholders+=("$token")
				target_regex+='(.+)'
				index=$((index + 2))
				continue
			fi

			if [[ "$next_char" == '(' ]] && token="$(extract_placeholder_token "$pattern" "$index")"; then
				pattern_placeholders+=("$token")
				target_regex+='(.+)'
				index=$((index + ${#token}))
				continue
			fi
		fi

		target_regex+="$(escape_ere_char "$char")"
		index=$((index + 1))
	done

	target_regex+='$'
}

render_help_description() {
	local description="$1"
	local token
	local capture
	local arg_index
	local value

	shift
	for token in "${pattern_placeholders[@]}"; do
		capture="${1:-}"
		arg_index="$(extract_placeholder_argument_index "$token")" || {
			shift || true
			continue
		}
		value="$(restore_placeholder_argument_value "$token" "$capture")"

		description="${description//"$token"/$value}"
		description="${description//"\$(${arg_index})"/$value}"
		description="${description//"\$${arg_index}"/$value}"
		shift || true
	done

	printf '%s' "$description"
}

emit_help() {
	local index
	local pattern
	local description
	local target
	local rendered_description
	local -a sorted_active_targets=()

	if ((${#active_targets[@]} > 0)); then
		mapfile -t sorted_active_targets < <(printf '%s\n' "${active_targets[@]}" | LC_ALL=C sort -u)
	fi

	for index in "${!help_patterns[@]}"; do
		pattern="${help_patterns[$index]}"
		description="${help_descriptions[$index]}"

		if [[ "$pattern" != *'$'* ]]; then
			if [[ -v active_target_set["$pattern"] && ! -v printed_targets["$pattern"] ]]; then
				printf '%-36s %s\n' "$pattern" "$description"
				printed_targets["$pattern"]=1
			fi
			continue
		fi

		build_target_regex "$pattern"
		for target in "${sorted_active_targets[@]}"; do
			if [[ -v printed_targets["$target"] ]]; then
				continue
			fi

			if [[ "$target" =~ $target_regex ]]; then
				rendered_description="$(render_help_description "$description" "${BASH_REMATCH[@]:1}")"
				printf '%-36s %s\n' "$target" "$rendered_description"
				printed_targets["$target"]=1
			fi
		done
	done
}

main() {
	load_make_database
	load_active_targets
	load_help_files
	load_help_declarations
	emit_help
}

main "$@"
