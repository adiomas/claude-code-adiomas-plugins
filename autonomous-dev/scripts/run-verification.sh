#!/bin/bash
set -euo pipefail

PROFILE_FILE=".claude/project-profile.yaml"
VERIFICATION_TYPE="${1:-all}"  # all, required, specific command name

if [[ ! -f "$PROFILE_FILE" ]]; then
    echo "ERROR: No project profile found at $PROFILE_FILE"
    echo "Run the project-detector skill first or create the profile manually."
    exit 1
fi

if ! command -v yq &>/dev/null; then
    echo "ERROR: yq is required. Install with: brew install yq"
    exit 1
fi

run_command() {
    local name="$1"
    local cmd
    cmd=$(yq -r ".commands.$name // \"\"" "$PROFILE_FILE")

    if [[ -z "$cmd" || "$cmd" == "null" ]]; then
        echo "SKIP: No $name command configured"
        return 0
    fi

    echo "RUNNING: $name ($cmd)"
    if eval "$cmd"; then
        echo "PASS: $name"
        return 0
    else
        echo "FAIL: $name"
        return 1
    fi
}

case "$VERIFICATION_TYPE" in
    all)
        FAILED=0
        for check in typecheck lint test build; do
            run_command "$check" || ((FAILED++)) || true
        done
        if [[ $FAILED -gt 0 ]]; then
            echo ""
            echo "SUMMARY: $FAILED verification(s) failed"
            exit 1
        else
            echo ""
            echo "SUMMARY: All verifications passed"
            exit 0
        fi
        ;;
    required)
        FAILED=0
        REQUIRED=$(yq -r '.verification.required[]' "$PROFILE_FILE" 2>/dev/null || echo "")
        if [[ -z "$REQUIRED" ]]; then
            echo "No required verifications configured"
            exit 0
        fi
        for check in $REQUIRED; do
            run_command "$check" || ((FAILED++)) || true
        done
        if [[ $FAILED -gt 0 ]]; then
            echo ""
            echo "SUMMARY: $FAILED required verification(s) failed"
            exit 1
        else
            echo ""
            echo "SUMMARY: All required verifications passed"
            exit 0
        fi
        ;;
    *)
        run_command "$VERIFICATION_TYPE"
        ;;
esac
