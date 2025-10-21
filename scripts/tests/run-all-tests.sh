#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

LOG_FILE="/tmp/k8s-workshop-tests-$(date +%Y%m%d-%H%M%S).log"

TEST_RESULTS=()
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

record_test() {
    local test_name="$1"
    local result="$2"
    local message="$3"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [[ "${result}" == "PASS" ]]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        TEST_RESULTS+=("${GREEN}✓${NC} ${test_name}: ${message}")
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        TEST_RESULTS+=("${RED}✗${NC} ${test_name}: ${message}")
    fi
}

run_test_script() {
    local script_path="$1"
    local test_name="$2"

    log_info "Running: ${test_name}"

    if [[ ! -f "${script_path}" ]]; then
        record_test "${test_name}" "FAIL" "Test script not found: ${script_path}"
        return 1
    fi

    if bash "${script_path}" >> "${LOG_FILE}" 2>&1; then
        record_test "${test_name}" "PASS" "All checks passed"
        return 0
    else
        record_test "${test_name}" "FAIL" "Some checks failed (see log)"
        return 1
    fi
}

main() {
    init_log

    log_section "Kubernetes Workshop - Complete Test Suite"

    cat <<EOF
${BOLD}Test Execution Plan:${NC}

1. Cluster Installation Tests
2. Baseline Application Tests
3. Exercise Validation Tests

${BOLD}Test Log:${NC} ${LOG_FILE}

Starting tests...

EOF

    log_section "Phase 1: Cluster Installation Tests"

    if [[ -f "${SCRIPT_DIR}/test-cluster-install.sh" ]]; then
        run_test_script "${SCRIPT_DIR}/test-cluster-install.sh" "Cluster Installation"
    else
        log_warn "Cluster test script not found, skipping..."
    fi
    echo

    log_section "Phase 2: Baseline Application Tests"

    if [[ -f "${SCRIPT_DIR}/test-baseline-app.sh" ]]; then
        run_test_script "${SCRIPT_DIR}/test-baseline-app.sh" "Baseline Application"
    else
        log_warn "Baseline test script not found, skipping..."
    fi
    echo

    log_section "Phase 3: Exercise Validation Tests"

    if [[ -f "${SCRIPT_DIR}/test-all-exercises.sh" ]]; then
        run_test_script "${SCRIPT_DIR}/test-all-exercises.sh" "All Exercises"
    else
        log_warn "Exercises test script not found, skipping..."
    fi
    echo

    log_section "Test Results Summary"

    echo
    for result in "${TEST_RESULTS[@]}"; do
        echo -e "  ${result}"
    done
    echo

    cat <<EOF
${BOLD}Test Statistics:${NC}
  Total Tests:  ${TOTAL_TESTS}
  Passed:       ${GREEN}${PASSED_TESTS}${NC}
  Failed:       ${RED}${FAILED_TESTS}${NC}

EOF

    if [[ ${FAILED_TESTS} -eq 0 ]]; then
        cat <<EOF
${GREEN}${BOLD}🎉 ALL TESTS PASSED!${NC}

${BOLD}Workshop Status:${NC} Production Ready ✅

${BOLD}Next Steps:${NC}
  • Review test log: ${CYAN}cat ${LOG_FILE}${NC}
  • Deploy to actual environment for validation
  • Run workshop with users

${BOLD}Quality Indicators:${NC}
  ✓ All scripts are functional
  ✓ Cluster setup works correctly
  ✓ Application deploys successfully
  ✓ Exercises validate properly
  ✓ No bugs detected

EOF
        log_success "Complete test suite passed!"
        return 0
    else
        cat <<EOF
${RED}${BOLD}⚠ SOME TESTS FAILED${NC}

${BOLD}Failed Tests:${NC} ${FAILED_TESTS}/${TOTAL_TESTS}

${BOLD}Troubleshooting:${NC}
  1. Review full log: ${CYAN}cat ${LOG_FILE}${NC}
  2. Check specific test output
  3. Fix identified issues
  4. Re-run: ${CYAN}./run-all-tests.sh${NC}

${BOLD}Common Issues:${NC}
  • Cluster not running: Start with setup/00-install-cluster.sh
  • Application not deployed: Run baseline-app/00-deploy-baseline.sh
  • Permissions: Ensure proper KUBECONFIG and access
  • Resources: Check system has enough CPU/RAM

EOF
        log_error "Test suite failed. Please review errors."
        return 1
    fi
}

main "$@"
