#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "${script_dir}/lib/common.sh"

project_root="$(pwd -P)"
make_bin="${ALMKFS_MAKE_BIN:-make}"
raw_makeoverrides="${__ALMKFS_RAW_MAKEOVERRIDES:-}"

normalize_directory_path() {
	local path="$1"

	realpath --relative-base="$project_root" --relative-to="$project_root" "$path"
}

default_env_make_file_from_directory_path() {
	local path="$1"

	if [[ "$path" == /* || "$path" == "." ]]; then
		printf '.env.mk'
	else
		printf '%s/.env.mk' "$path"
	fi
}

almakefiles_directory_path="$(
	normalize_directory_path "${ALMKFS_DIRECTORY_PATH:-$(dirname "$script_dir")}"
)"
env_make_file="${ALMKFS_ENV_FILE:-$(default_env_make_file_from_directory_path "$almakefiles_directory_path")}"

declare -a scan_files=()
declare -a question_default_vars=()
declare -a project_vars=()

declare -A question_default_rhs=()
declare -A question_default_sources=()
declare -A question_default_source_lists=()
declare -A question_default_counts=()
declare -A project_var_seen=()

is_gnu_make_system_var() {
	local var_name="$1"

	case "$var_name" in
		AR | ARFLAGS | AS | CC | CFLAGS | CO | COMSPEC | CPP | CPPFLAGS | CTANGLE | CURDIR | CWEAVE | CXX | CXXFLAGS | FC | F77 | FFLAGS | GFLAGS | GET | GNUMAKEFLAGS | LDFLAGS | LDLIBS | LEX | LFLAGS | LINT | LOADLIBES | M2C | MAKE | MAKECMDGOALS | MAKEFILE_LIST | MAKEFILES | MAKEFLAGS | MAKELEVEL | MAKEOVERRIDES | MAKEINFO | MAKE_HOST | MAKE_RESTARTS | MAKE_TERMERR | MAKE_TERMOUT | MAKE_VERSION | MFLAGS | OBJC | OBJCFLAGS | OUTPUT_OPTION | PFLAGS | PC | RFLAGS | RM | SHELL | SUFFIXES | TARGET_ARCH | TANGLE | TEX | TEXI2DVI | VPATH | WEAVE | YACC | YFLAGS)
			return 0
			;;
	esac

	return 1
}

is_env_make_public_var_allowed() {
	local var_name="$1"

	if [[ "$var_name" == __ALMKFS_* ]]; then
		return 1
	fi

	if is_gnu_make_system_var "$var_name"; then
		return 1
	fi

	return 0
}

report_invalid_env_make_line() {
	local path="$1"
	local line_number="$2"
	local reason="$3"

	if [[ -e "$path" ]]; then
		path="$(realpath "$path")"
	fi

	printf 'Invalid %s:%s: %s\n' "$path" "$line_number" "$reason" >&2
	return 1
}

validate_env_make_file() {
	local path="$1"
	local line
	local line_number=0
	local var_name

	if [[ ! -f "$path" ]]; then
		return 0
	fi

	# shellcheck disable=SC2094
	while IFS= read -r line || [[ -n "$line" ]]; do
		line_number=$((line_number + 1))

		if [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]]; then
			continue
		fi

		if [[ "$line" =~ ^[[:space:]]*([^:#=[:space:]]+)[[:space:]]*(=|:=|::=|\+=)[[:space:]]*(.*)$ ]]; then
			var_name="${BASH_REMATCH[1]}"

			if [[ "$var_name" == __ALMKFS_* ]]; then
				report_invalid_env_make_line "$path" "$line_number" "__ALMKFS_* variables are not allowed in .env.mk"
				return 1
			fi

			if is_gnu_make_system_var "$var_name"; then
				report_invalid_env_make_line "$path" "$line_number" "GNU Make system variables are not allowed in .env.mk"
				return 1
			fi

			continue
		fi

		if [[ "$line" =~ ^[[:space:]]*[^:#=[:space:]]+[[:space:]]*\?=[[:space:]]*(.*)$ ]]; then
			report_invalid_env_make_line "$path" "$line_number" "?= assignments are not allowed in .env.mk"
			return 1
		fi

		if [[ "$line" =~ ^[[:space:]]*[^:#=[:space:]]+[[:space:]]*!=[[:space:]]*(.*)$ ]]; then
			report_invalid_env_make_line "$path" "$line_number" "!= assignments are not allowed in .env.mk"
			return 1
		fi

		if [[ "$line" =~ ^[[:space:]]*override([[:space:]]|$) ]]; then
			report_invalid_env_make_line "$path" "$line_number" "override directives are not allowed in .env.mk"
			return 1
		fi

		if [[ "$line" =~ ^[[:space:]]*export([[:space:]]|$) ]]; then
			report_invalid_env_make_line "$path" "$line_number" "export directives are not allowed in .env.mk"
			return 1
		fi

		if [[ "$line" =~ ^[[:space:]]*private([[:space:]]|$) ]]; then
			report_invalid_env_make_line "$path" "$line_number" "private directives are not allowed in .env.mk"
			return 1
		fi

		if [[ "$line" =~ ^[[:space:]]*undefine([[:space:]]|$) ]]; then
			report_invalid_env_make_line "$path" "$line_number" "undefine directives are not allowed in .env.mk"
			return 1
		fi

		if [[ "$line" =~ ^[[:space:]]*(define|endef)([[:space:]]|$) ]]; then
			report_invalid_env_make_line "$path" "$line_number" "define blocks are not allowed in .env.mk"
			return 1
		fi

		if [[ "$line" =~ ^[[:space:]]*(ifdef|ifndef|ifeq|ifneq|else|endif)([[:space:]]|$) ]]; then
			report_invalid_env_make_line "$path" "$line_number" "conditional directives are not allowed in .env.mk"
			return 1
		fi

		if [[ "$line" =~ ^[[:space:]]*(-?include|sinclude)([[:space:]]|$) ]]; then
			report_invalid_env_make_line "$path" "$line_number" "include directives are not allowed in .env.mk"
			return 1
		fi

		if [[ "$line" =~ ^[[:space:]]*[^#[:space:]][^=]*::?($|[[:space:]].*) ]]; then
			report_invalid_env_make_line "$path" "$line_number" "targets and rules are not allowed in .env.mk"
			return 1
		fi

		report_invalid_env_make_line "$path" "$line_number" "unsupported syntax in .env.mk"
		return 1
	done <"$path"
}

normalize_scan_path() {
	local path="$1"

	while [[ "$path" == ./* ]]; do
		path="${path#./}"
	done

	printf '%s' "$path"
}

is_hidden_make_scan_file() {
	local path="$1"
	local basename="${path##*/}"

	case "$basename" in
		.mk | .makefile | .*.mk | .*.makefile)
			return 0
			;;
	esac

	return 1
}

append_scan_path() {
	local list_name="$1"
	local path="$2"
	# shellcheck disable=SC2034
	local -n append_scan_path_list="$list_name"

	path="$(normalize_scan_path "$path")"

	if [[ -f "$path" ]]; then
		append_unique append_scan_path_list "$path"
	fi
}

collect_makefile_candidates_from_root() {
	local list_name="$1"
	local path

	append_scan_path "$list_name" "makefile"
	append_scan_path "$list_name" "Makefile"
	append_scan_path "$list_name" "GNUmakefile"

	while IFS= read -r path; do
		append_scan_path "$list_name" "$path"
	done < <(find . -maxdepth 1 -type f \( -name '*.mk' -o -name '*.makefile' \) -printf '%P\n' | LC_ALL=C sort)
}

collect_makefile_candidates_from_dir() {
	local list_name="$1"
	local dir="$2"
	local path

	if [[ ! -d "$dir" ]]; then
		return 0
	fi

	while IFS= read -r path; do
		append_scan_path "$list_name" "$path"
	done < <(find "$dir" -type f \( -name 'makefile' -o -name 'Makefile' -o -name '*.mk' -o -name '*.makefile' \) -print | LC_ALL=C sort)
}

collect_dropin_makefile_candidates() {
	local list_name="$1"
	local path

	append_scan_path "$list_name" "$almakefiles_directory_path/include.mk"

	if [[ ! -d "$almakefiles_directory_path/mk" ]]; then
		return 0
	fi

	while IFS= read -r path; do
		append_scan_path "$list_name" "$path"
	done < <(find "$almakefiles_directory_path/mk" -maxdepth 1 -type f \( -name '*.mk' -o -name '*.makefile' \) -print | LC_ALL=C sort)
}

collect_makefile_candidates_from_csv_dirs() {
	local list_name="$1"
	local dirs_csv="$2"
	local dir

	while IFS= read -r dir; do
		collect_makefile_candidates_from_dir "$list_name" "$dir"
	done < <(split_csv "$dirs_csv")
}

collect_makefile_candidates_from_csv_globs() {
	local list_name="$1"
	local globs_csv="$2"
	local pattern
	local match

	shopt -s nullglob globstar
	while IFS= read -r pattern; do
		for match in $pattern; do
			append_scan_path "$list_name" "$match"
		done
	done < <(split_csv "$globs_csv")
	shopt -u nullglob globstar
}

collect_makefile_candidates_from_csv_files() {
	local list_name="$1"
	local files_csv="$2"
	local path

	while IFS= read -r path; do
		append_scan_path "$list_name" "$path"
	done < <(split_csv "$files_csv")
}

collect_scan_files() {
	local path
	local -a include_scan_files=()
	local -a exclude_scan_files=()
	local -a filtered_scan_files=()
	local -a sorted_files=()
	declare -A exclude_scan_file_set=()

	scan_files=()

	collect_makefile_candidates_from_root include_scan_files
	collect_dropin_makefile_candidates include_scan_files
	collect_makefile_candidates_from_csv_dirs include_scan_files "${ALMKFS_SCAN_INCLUDE_DIRS_CSV:-}"
	collect_makefile_candidates_from_csv_globs include_scan_files "${ALMKFS_SCAN_INCLUDE_GLOBS_CSV:-}"

	collect_makefile_candidates_from_csv_dirs exclude_scan_files "${ALMKFS_SCAN_EXCLUDE_DIRS_CSV:-}"
	collect_makefile_candidates_from_csv_globs exclude_scan_files "${ALMKFS_SCAN_EXCLUDE_GLOBS_CSV:-}"
	collect_makefile_candidates_from_csv_files exclude_scan_files "${__ALMKFS_SCAN_EXCLUDE_MAKEFILES_CSV:-}"

	for path in "${exclude_scan_files[@]}"; do
		exclude_scan_file_set["$path"]=1
	done

	for path in "${include_scan_files[@]}"; do
		if is_hidden_make_scan_file "$path"; then
			continue
		fi

		if [[ -v exclude_scan_file_set["$path"] ]]; then
			continue
		fi

		append_unique filtered_scan_files "$path"
	done

	if ((${#filtered_scan_files[@]} > 0)); then
		mapfile -t sorted_files < <(printf '%s\n' "${filtered_scan_files[@]}" | LC_ALL=C sort -u)
		scan_files=("${sorted_files[@]}")
	fi
}

reset_scan_results() {
	question_default_vars=()
	question_default_rhs=()
	question_default_sources=()
	question_default_source_lists=()
	question_default_counts=()
	project_vars=()
	project_var_seen=()
}

recipe_prefix_from_rhs() {
	local rhs="$1"

	rhs="$(trim_whitespace "$rhs")"
	if [[ -n "$rhs" ]]; then
		printf '%s' "${rhs:0:1}"
	else
		printf '\t'
	fi
}

record_scanned_assignment() {
	local file="$1"
	local line_number="$2"
	local var_name="$3"
	local operator="$4"
	local rhs="$5"

	if [[ ! -v project_var_seen["$var_name"] ]]; then
		project_var_seen["$var_name"]=1
		project_vars+=("$var_name")
	fi

	if [[ "$operator" != '?=' ]]; then
		return 0
	fi

	if [[ "$var_name" == "ALMKFS_ENV_FILE" ]]; then
		return 0
	fi

	if ! is_env_make_public_var_allowed "$var_name"; then
		return 0
	fi

	if [[ ! -v question_default_sources["$var_name"] ]]; then
		question_default_vars+=("$var_name")
		question_default_rhs["$var_name"]="$rhs"
		question_default_sources["$var_name"]="$file:$line_number"
		question_default_source_lists["$var_name"]="$file:$line_number"
		question_default_counts["$var_name"]=1
	else
		question_default_counts["$var_name"]=$((question_default_counts["$var_name"] + 1))
		question_default_source_lists["$var_name"]+=$'\n'"$file:$line_number"
	fi
}

scan_assignments_in_file() {
	local file="$1"
	local line
	local line_number=0
	local var_name
	local operator
	local rhs
	local recipe_prefix=$'\t'
	local define_depth=0

	# shellcheck disable=SC2094
	while IFS= read -r line || [[ -n "$line" ]]; do
		line_number=$((line_number + 1))

		if ((define_depth > 0)); then
			if [[ "$line" =~ ^[[:space:]]*(override[[:space:]]+)?define([[:space:]]|$) ]]; then
				define_depth=$((define_depth + 1))
			fi

			if [[ "$line" =~ ^[[:space:]]*endef([[:space:]]|$) ]]; then
				define_depth=$((define_depth - 1))
			fi

			continue
		fi

		if [[ -n "$line" && "${line:0:1}" == "$recipe_prefix" ]]; then
			continue
		fi

		if [[ "$line" =~ ^[[:space:]]*(override[[:space:]]+)?define([[:space:]]|$) ]]; then
			define_depth=1
			continue
		fi

		if [[ "$line" =~ ^[[:space:]]*(override[[:space:]]+)?([^:#=[:space:]]+)[[:space:]]*([:+?!]?=)[[:space:]]*(.*)$ ]]; then
			var_name="${BASH_REMATCH[2]}"
			operator="${BASH_REMATCH[3]}"
			rhs="${BASH_REMATCH[4]}"

			record_scanned_assignment "$file" "$line_number" "$var_name" "$operator" "$rhs"

			if [[ "$var_name" == ".RECIPEPREFIX" ]]; then
				recipe_prefix="$(recipe_prefix_from_rhs "$rhs")"
			fi
		fi
	done <"$file"
}

scan_assignments() {
	local file

	reset_scan_results
	for file in "${scan_files[@]}"; do
		scan_assignments_in_file "$file"
	done
}

warn_duplicate_defaults() {
	local var_name

	for var_name in "${question_default_vars[@]}"; do
		if ((question_default_counts["$var_name"] > 1)); then
			printf 'Skipping duplicate ?= default for %s\n' "$var_name" >&2
			printf '%s\n' "${question_default_source_lists["$var_name"]}" >&2
			printf "try 'make var.debug' for more info\n" >&2
		fi
	done
}

render_env_make() {
	local var_name

	for var_name in "${question_default_vars[@]}"; do
		if ((question_default_counts["$var_name"] > 1)); then
			continue
		fi

		printf '%s = %s\n' "$var_name" "${question_default_rhs["$var_name"]}"
	done
}

env_make_file_ends_with_newline() {
	local path="$1"
	local trailing_newline_lines

	if [[ ! -s "$path" ]]; then
		return 0
	fi

	trailing_newline_lines="$(tail -c 1 "$path" | wc -l)"
	[[ "$trailing_newline_lines" -eq 1 ]]
}

prepare_env_make_defaults() {
	collect_scan_files
	scan_assignments
	load_database_records
	filter_question_defaults_with_database
	warn_duplicate_defaults
}

write_env_make() {
	local status="$1"

	mkdir -p "$(dirname "$env_make_file")"
	render_env_make | write_file_atomic "$env_make_file" "$env_make_file"
	printf '%s %s\n' "$status" "$env_make_file"
}

collect_existing_env_make_vars() {
	local path="$1"
	local line
	local line_number=0
	local var_name
	declare -gA existing_env_make_vars=()

	if [[ ! -f "$path" ]]; then
		return 0
	fi

	validate_env_make_file "$path"

	while IFS= read -r line || [[ -n "$line" ]]; do
		line_number=$((line_number + 1))
		if [[ "$line" =~ ^[[:space:]]*([^:#=[:space:]]+)[[:space:]]*(=|:=|::=|\+=)[[:space:]]*(.*)$ ]]; then
			var_name="${BASH_REMATCH[1]}"
			existing_env_make_vars["$var_name"]=1
		fi
	done <"$path"
}

bootstrap_env_make() {
	prepare_env_make_defaults
	write_env_make "Created"
}

reinit_env_make() {
	prepare_env_make_defaults
	write_env_make "Reinitialized"
}

sync_env_make() {
	local var_name
	local appended=0
	local -a missing_default_vars=()

	prepare_env_make_defaults
	validate_env_make_file "$env_make_file"
	collect_existing_env_make_vars "$env_make_file"

	if [[ ! -f "$env_make_file" ]]; then
		write_env_make "Created"
		return 0
	fi

	for var_name in "${question_default_vars[@]}"; do
		if ((question_default_counts["$var_name"] > 1)); then
			continue
		fi

		if [[ -v existing_env_make_vars["$var_name"] ]]; then
			continue
		fi

		missing_default_vars+=("$var_name")
		printf 'Appended %s to %s\n' "$var_name" "$env_make_file"
		appended=1
	done

	if [[ "$appended" -eq 0 ]]; then
		printf 'No new defaults to append to %s\n' "$env_make_file"
		return 0
	fi

	{
		cat "$env_make_file"
		if ! env_make_file_ends_with_newline "$env_make_file"; then
			printf '\n'
		fi

		for var_name in "${missing_default_vars[@]}"; do
			printf '%s = %s\n' "$var_name" "${question_default_rhs["$var_name"]}"
		done
	} | write_file_atomic "$env_make_file" "$env_make_file"
}

load_database_records() {
	local database_file
	local var_name
	local origin
	local source
	local value
	local -a make_command=()

	declare -gA database_value=()
	declare -gA database_origin=()
	declare -gA database_source=()
	declare -gA parsed_makefile_set=()

	database_file="$(mktemp)"
	make_command=("$make_bin" -pnRr help)

	if [[ -n "$raw_makeoverrides" ]]; then
		MAKEFLAGS=" -- $raw_makeoverrides" "${make_command[@]}" >"$database_file" 2>/dev/null
	else
		"${make_command[@]}" >"$database_file" 2>/dev/null
	fi

	while IFS=$'\t' read -r var_name origin source value; do
		database_value["$var_name"]="$value"
		database_origin["$var_name"]="$origin"
		database_source["$var_name"]="$source"

		if [[ "$source" == *:* ]] && [[ "$origin" == "file" || "$origin" == "override" ]]; then
			parsed_makefile_set["${source%:*}"]=1
		fi
	done < <(
		awk '
			function emit_record(current_comment, current_line, line_parts, comment_parts, origin, source, value) {
				split("", line_parts)
				split("", comment_parts)
				if (!match(current_line, /^([^:#=[:space:]]+)[[:space:]]*[:+?!]?=[[:space:]]*(.*)$/, line_parts)) {
					return
				}

				origin = "unknown"
				source = "unknown"
				if (current_comment == "# command line") {
					origin = "command line"
					source = "command line"
				} else if (current_comment == "# environment") {
					origin = "environment"
					source = "environment"
				} else if (current_comment == "# environment under -e") {
					origin = "environment override"
					source = "environment override"
				} else if (current_comment == "# default") {
					origin = "default"
					source = "default"
				} else if (current_comment == "# automatic") {
					origin = "automatic"
					source = "automatic"
				} else if (current_comment == "# makefile") {
					origin = "file"
					source = "file"
				} else if (current_comment == "# '\''override'\'' directive") {
					origin = "override"
					source = "override"
				} else if (match(current_comment, /^# '\''override'\'' directive \(from '\''([^'\'']+)'\'', line ([0-9]+)\)$/, comment_parts)) {
					origin = "override"
					source = comment_parts[1] ":" comment_parts[2]
				} else if (match(current_comment, /^# makefile \(from '\''([^'\'']+)'\'', line ([0-9]+)\)$/, comment_parts)) {
					origin = "file"
					source = comment_parts[1] ":" comment_parts[2]
				}

				value = line_parts[2]
				printf "%s\t%s\t%s\t%s\n", line_parts[1], origin, source, value
			}

			/^# / {
				comment = $0
				next
			}

			{
				emit_record(comment, $0)
				comment = ""
			}
			' "$database_file"
		)

	rm -f "$database_file"
}

filter_question_defaults_with_database() {
	local var_name
	local source
	local source_file
	local database_var_origin
	local database_var_source
	local -a filtered_question_default_vars=()
	declare -A filtered_question_default_rhs=()
	declare -A filtered_question_default_sources=()
	declare -A filtered_question_default_source_lists=()
	declare -A filtered_question_default_counts=()

	for var_name in "${question_default_vars[@]}"; do
		if ((question_default_counts["$var_name"] > 1)); then
			filtered_question_default_vars+=("$var_name")
			filtered_question_default_rhs["$var_name"]="${question_default_rhs["$var_name"]}"
			filtered_question_default_sources["$var_name"]="${question_default_sources["$var_name"]}"
			filtered_question_default_source_lists["$var_name"]="${question_default_source_lists["$var_name"]}"
			filtered_question_default_counts["$var_name"]="${question_default_counts["$var_name"]}"
			continue
		fi

		source="${question_default_sources["$var_name"]}"
		source_file="${source%:*}"

		if [[ -v parsed_makefile_set["$source_file"] ]]; then
			if [[ ! -v database_origin["$var_name"] ]]; then
				continue
			fi

			database_var_origin="${database_origin["$var_name"]}"
			database_var_source="${database_source["$var_name"]}"
			if [[ "$database_var_source" != "$source" ]] \
				&& [[ "${database_var_source%:*}" != "$env_make_file" ]] \
				&& [[ "$database_var_origin" != "command line" ]] \
				&& [[ "$database_var_origin" != "environment" ]] \
				&& [[ "$database_var_origin" != "environment override" ]]; then
				continue
			fi
		fi

		filtered_question_default_vars+=("$var_name")
		filtered_question_default_rhs["$var_name"]="${question_default_rhs["$var_name"]}"
		filtered_question_default_sources["$var_name"]="$source"
		filtered_question_default_source_lists["$var_name"]="${question_default_source_lists["$var_name"]}"
		filtered_question_default_counts["$var_name"]="${question_default_counts["$var_name"]}"
	done

	question_default_vars=("${filtered_question_default_vars[@]}")

	unset question_default_rhs question_default_sources question_default_source_lists question_default_counts
	declare -gA question_default_rhs=()
	declare -gA question_default_sources=()
	declare -gA question_default_source_lists=()
	declare -gA question_default_counts=()

	for var_name in "${question_default_vars[@]}"; do
		question_default_rhs["$var_name"]="${filtered_question_default_rhs["$var_name"]}"
		question_default_sources["$var_name"]="${filtered_question_default_sources["$var_name"]}"
		question_default_source_lists["$var_name"]="${filtered_question_default_source_lists["$var_name"]}"
		question_default_counts["$var_name"]="${filtered_question_default_counts["$var_name"]}"
	done
}

print_debug_report() {
	local mode="$1"
	local var_name
	local -a vars_to_print=()
	declare -A seen_vars=()

	collect_scan_files
	scan_assignments
	load_database_records
	filter_question_defaults_with_database

	if [[ "$mode" == "full" ]]; then
		vars_to_print=("${project_vars[@]}")
	else
		vars_to_print=("${question_default_vars[@]}")
	fi

	for var_name in "${vars_to_print[@]}"; do
		if [[ -v seen_vars["$var_name"] ]]; then
			continue
		fi
		seen_vars["$var_name"]=1

		if [[ ! -v database_origin["$var_name"] ]]; then
			continue
		fi

		printf '%s\n' "$var_name"
		printf '  value: %s\n' "${database_value["$var_name"]}"
		printf '  origin: %s\n' "${database_origin["$var_name"]}"
		printf '  source: %s\n' "${database_source["$var_name"]}"
	done
}

main() {
	local command="${1:-}"

	case "$command" in
		bootstrap)
			bootstrap_env_make
			;;
		reinit)
			reinit_env_make
			;;
		sync)
			sync_env_make
			;;
		validate)
			validate_env_make_file "$env_make_file"
			;;
		debug)
			if [[ "${2:-}" == "--full" ]]; then
				print_debug_report "full"
			else
				print_debug_report "short"
			fi
			;;
		*)
			printf 'Unsupported env-make command: %s\n' "$command" >&2
			exit 1
			;;
	esac
}

main "$@"
