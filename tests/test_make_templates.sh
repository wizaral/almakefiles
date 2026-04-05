#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
export REPO_ROOT

. "${TESTS_DIR}/lib/test_helpers.sh"
. "${TESTS_DIR}/suites/env-init-suite.sh"
. "${TESTS_DIR}/suites/env-make-suite.sh"
. "${TESTS_DIR}/suites/system-suite.sh"

main() {
	run_env_init_suite
	run_env_make_suite
	run_system_suite
}

main "$@"
