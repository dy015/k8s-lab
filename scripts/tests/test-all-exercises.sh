#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../helpers" && pwd)"
EXERCISES_DIR="$(cd "${SCRIPT_DIR}/../../exercises" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

TESTS_PASSED=0
TESTS_FAILED=0

check_exercise_files() {
    local exercise_dir="$1"
    local exercise_name="$2"

    log_info "Checking: ${exercise_name}"

    local required_files=("README.md" "break.sh" "fix.sh" "verify.sh" "reset.sh")
    local all_exist=true

    for file in "${required_files[@]}"; do
        if [[ ! -f "${exercise_dir}/${file}" ]]; then
            log_error "  Missing: ${file}"
            all_exist=false
        fi
    done

    for script in break.sh fix.sh verify.sh reset.sh; do
        if [[ -f "${exercise_dir}/${script}" ]] && [[ ! -x "${exercise_dir}/${script}" ]]; then
            log_error "  Not executable: ${script}"
            all_exist=false
        fi
    done

    if ${all_exist}; then
        print_status "ok" "${exercise_name} - All files present and executable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_status "fail" "${exercise_name} - Missing or non-executable files"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

check_script_syntax() {
    local script_path="$1"
    local script_name="$2"

    if bash -n "${script_path}" 2>/dev/null; then
        return 0
    else
        log_error "Syntax error in: ${script_name}"
        return 1
    fi
}

main() {
    init_log

    log_section "Exercise Validation Tests"

    local exercises=(
        "01-crashloopbackoff:Exercise 01 - CrashLoopBackOff"
        "02-imagepullbackoff:Exercise 02 - ImagePullBackOff"
        "03-service-unreachable:Exercise 03 - Service Unreachable"
        "04-configmap-missing:Exercise 04 - ConfigMap Missing"
        "05-secret-missing:Exercise 05 - Secret Missing"
        "06-oom-killed:Exercise 06 - OOM Killed"
        "07-liveness-probe-fail:Exercise 07 - Liveness Probe Fail"
        "08-readiness-probe-fail:Exercise 08 - Readiness Probe Fail"
        "09-pvc-pending:Exercise 09 - PVC Pending"
        "10-dns-not-working:Exercise 10 - DNS Not Working"
        "11-ingress-404:Exercise 11 - Ingress 404"
        "12-rbac-forbidden:Exercise 12 - RBAC Forbidden"
        "13-network-policy-blocked:Exercise 13 - Network Policy Blocked"
        "14-node-pressure:Exercise 14 - Node Pressure"
        "15-rollout-stuck:Exercise 15 - Rollout Stuck"
    )

    log_step 1 "Checking exercise files and permissions"
    echo

    for exercise in "${exercises[@]}"; do
        IFS=':' read -r dir_name display_name <<< "${exercise}"
        exercise_dir="${EXERCISES_DIR}/${dir_name}"

        if [[ -d "${exercise_dir}" ]]; then
            check_exercise_files "${exercise_dir}" "${display_name}"
        else
            log_error "Exercise directory not found: ${dir_name}"
            print_status "fail" "${display_name} - Directory missing"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    done

    echo
    log_step 2 "Checking script syntax"
    echo

    local syntax_errors=0

    for exercise in "${exercises[@]}"; do
        IFS=':' read -r dir_name display_name <<< "${exercise}"
        exercise_dir="${EXERCISES_DIR}/${dir_name}"

        if [[ -d "${exercise_dir}" ]]; then
            for script in break.sh fix.sh verify.sh reset.sh; do
                if [[ -f "${exercise_dir}/${script}" ]]; then
                    if ! check_script_syntax "${exercise_dir}/${script}" "${dir_name}/${script}"; then
                        syntax_errors=$((syntax_errors + 1))
                    fi
                fi
            done
        fi
    done

    if [[ ${syntax_errors} -eq 0 ]]; then
        print_status "ok" "All scripts have valid syntax"
    else
        print_status "fail" "${syntax_errors} scripts have syntax errors"
        TESTS_FAILED=$((TESTS_FAILED + syntax_errors))
    fi

    echo
    log_step 3 "Checking helper scripts"
    echo

    local helpers=("colors.sh" "logger.sh" "validators.sh")
    local helpers_ok=true

    for helper in "${helpers[@]}"; do
        if [[ -f "${HELPERS_DIR}/${helper}" ]]; then
            if check_script_syntax "${HELPERS_DIR}/${helper}" "helpers/${helper}"; then
                print_status "ok" "Helper script: ${helper}"
            else
                helpers_ok=false
            fi
        else
            log_error "Helper script missing: ${helper}"
            helpers_ok=false
        fi
    done

    if ! ${helpers_ok}; then
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi

    echo
    log_section "Test Summary"
    echo "  Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo "  Failed: ${RED}${TESTS_FAILED}${NC}"

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        log_success "All exercise validation tests passed!"
        cat <<EOF

${BOLD}Validation Results:${NC}
  ✓ All 15 exercises have required files
  ✓ All scripts are executable
  ✓ All scripts have valid syntax
  ✓ Helper scripts are present and valid

${BOLD}Exercises Ready:${NC}
  • 01-05: Basic level exercises
  • 06-10: Medium level exercises
  • 11-15: Medium-advanced exercises

EOF
        return 0
    else
        log_error "${TESTS_FAILED} exercise validation test(s) failed"
        cat <<EOF

${BOLD}Issues Found:${NC}
  • Missing or non-executable files
  • Syntax errors in scripts
  • Missing helper scripts

${BOLD}Action Required:${NC}
  Review errors above and fix issues before running workshop.

EOF
        return 1
    fi
}

main "$@"
