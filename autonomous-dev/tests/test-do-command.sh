#!/usr/bin/env bash
#
# test-do-command.sh - Integration test for /do command flow
#
# Tests the AGI-like interface components end-to-end
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$TEST_DIR")"

#
# Test utilities
#

log_test() {
    echo -e "\n${YELLOW}TEST:${NC} $1"
    ((TESTS_RUN++))
}

pass() {
    echo -e "  ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "  ${RED}✗ FAIL:${NC} $1"
    ((TESTS_FAILED++))
}

assert_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        pass
    else
        fail "File not found: $file"
    fi
}

assert_command_syntax() {
    local script="$1"
    if bash -n "$script" 2>/dev/null; then
        pass
    else
        fail "Syntax error in: $script"
    fi
}

assert_json_valid() {
    local file="$1"
    if jq '.' "$file" > /dev/null 2>&1; then
        pass
    else
        fail "Invalid JSON: $file"
    fi
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        pass
    else
        fail "Pattern '$pattern' not found in: $file"
    fi
}

#
# Component tests
#

test_bin_scripts() {
    echo -e "\n${YELLOW}=== Testing bin/ scripts ===${NC}"

    log_test "claude-agi exists and has valid syntax"
    assert_file_exists "$PLUGIN_ROOT/bin/claude-agi"
    bash -n "$PLUGIN_ROOT/bin/claude-agi" && pass || fail "Syntax error"

    log_test "install-claude-agi.sh exists and has valid syntax"
    assert_file_exists "$PLUGIN_ROOT/bin/install-claude-agi.sh"
    bash -n "$PLUGIN_ROOT/bin/install-claude-agi.sh" && pass || fail "Syntax error"
}

test_scripts() {
    echo -e "\n${YELLOW}=== Testing scripts/ ===${NC}"

    local scripts=(
        "state-manager.sh"
        "local-memory.sh"
        "global-memory.sh"
        "extract-learnings.sh"
        "memory-cleanup.sh"
        "request-handoff.sh"
    )

    for script in "${scripts[@]}"; do
        log_test "$script exists and has valid syntax"
        local path="$PLUGIN_ROOT/scripts/$script"
        if [[ -f "$path" ]]; then
            if bash -n "$path" 2>/dev/null; then
                pass
            else
                fail "Syntax error"
            fi
        else
            fail "File not found"
        fi
    done
}

test_commands() {
    echo -e "\n${YELLOW}=== Testing commands/ ===${NC}"

    log_test "/do command exists"
    assert_file_exists "$PLUGIN_ROOT/commands/do.md"

    log_test "/do command has name field"
    assert_contains "$PLUGIN_ROOT/commands/do.md" "^name: do"

    log_test "/status command exists"
    assert_file_exists "$PLUGIN_ROOT/commands/status.md"

    log_test "/cancel command exists"
    assert_file_exists "$PLUGIN_ROOT/commands/cancel.md"

    log_test "Legacy /auto has deprecation notice"
    assert_contains "$PLUGIN_ROOT/commands/auto.md" "DEPRECATED"

    log_test "Legacy /auto-smart has deprecation notice"
    assert_contains "$PLUGIN_ROOT/commands/auto-smart.md" "DEPRECATED"

    log_test "Legacy /auto-lite has deprecation notice"
    assert_contains "$PLUGIN_ROOT/commands/auto-lite.md" "DEPRECATED"
}

test_engine_skills() {
    echo -e "\n${YELLOW}=== Testing engine/ skills ===${NC}"

    local skills=(
        "parser.md"
        "enricher.md"
        "classifier.md"
        "resolver.md"
        "strategist.md"
    )

    for skill in "${skills[@]}"; do
        log_test "engine/$skill exists"
        assert_file_exists "$PLUGIN_ROOT/engine/$skill"
    done

    log_test "Parser has reference resolution"
    assert_contains "$PLUGIN_ROOT/engine/parser.md" "reference"

    log_test "Classifier has complexity scoring"
    assert_contains "$PLUGIN_ROOT/engine/classifier.md" "complexity"

    log_test "Resolver has critical action detection"
    assert_contains "$PLUGIN_ROOT/engine/resolver.md" "critical"
}

test_execution_skills() {
    echo -e "\n${YELLOW}=== Testing execution/ skills ===${NC}"

    local skills=(
        "direct-executor.md"
        "orchestrated-executor.md"
        "checkpoint-manager.md"
        "failure-handler.md"
        "handoff-manager.md"
        "tdd-executor.md"
    )

    for skill in "${skills[@]}"; do
        log_test "execution/$skill exists"
        assert_file_exists "$PLUGIN_ROOT/execution/$skill"
    done

    log_test "TDD executor has RED-GREEN-REFACTOR"
    assert_contains "$PLUGIN_ROOT/execution/tdd-executor.md" "RED"
    assert_contains "$PLUGIN_ROOT/execution/tdd-executor.md" "GREEN"
    assert_contains "$PLUGIN_ROOT/execution/tdd-executor.md" "REFACTOR"

    log_test "Failure handler has escalation levels"
    assert_contains "$PLUGIN_ROOT/execution/failure-handler.md" "Retry"
    assert_contains "$PLUGIN_ROOT/execution/failure-handler.md" "Pivot"
}

test_memory_skills() {
    echo -e "\n${YELLOW}=== Testing memory/ skills ===${NC}"

    local skills=(
        "local-manager.md"
        "global-manager.md"
        "learner.md"
        "forgetter.md"
    )

    for skill in "${skills[@]}"; do
        log_test "memory/$skill exists"
        assert_file_exists "$PLUGIN_ROOT/memory/$skill"
    done
}

test_hooks() {
    echo -e "\n${YELLOW}=== Testing hooks/ ===${NC}"

    log_test "hooks.json is valid JSON"
    assert_json_valid "$PLUGIN_ROOT/hooks/hooks.json"

    log_test "hooks.json has v4 description"
    assert_contains "$PLUGIN_ROOT/hooks/hooks.json" "v4.0"

    log_test "session-end-learning.sh exists and has valid syntax"
    assert_file_exists "$PLUGIN_ROOT/hooks/session-end-learning.sh"
    bash -n "$PLUGIN_ROOT/hooks/session-end-learning.sh" && pass || fail "Syntax error"
}

test_schemas() {
    echo -e "\n${YELLOW}=== Testing schemas/ ===${NC}"

    log_test "state.schema.json exists"
    assert_file_exists "$PLUGIN_ROOT/schemas/state.schema.json"

    log_test "state.schema.json is valid JSON"
    assert_json_valid "$PLUGIN_ROOT/schemas/state.schema.json"
}

test_plugin_manifest() {
    echo -e "\n${YELLOW}=== Testing plugin manifest ===${NC}"

    log_test "plugin.json exists"
    assert_file_exists "$PLUGIN_ROOT/.claude-plugin/plugin.json"

    log_test "plugin.json is valid JSON"
    assert_json_valid "$PLUGIN_ROOT/.claude-plugin/plugin.json"

    log_test "plugin.json has version 4.0.0"
    local version
    version=$(jq -r '.version' "$PLUGIN_ROOT/.claude-plugin/plugin.json")
    if [[ "$version" == "4.0.0" ]]; then
        pass
    else
        fail "Expected version 4.0.0, got $version"
    fi
}

test_intent_flow() {
    echo -e "\n${YELLOW}=== Testing intent flow documentation ===${NC}"

    log_test "Parser → Enricher flow documented"
    assert_contains "$PLUGIN_ROOT/engine/enricher.md" "Parser"

    log_test "Enricher → Classifier flow documented"
    assert_contains "$PLUGIN_ROOT/engine/classifier.md" "Enricher"

    log_test "Classifier → Resolver flow documented"
    assert_contains "$PLUGIN_ROOT/engine/resolver.md" "Classifier"

    log_test "Resolver → Strategist flow documented"
    assert_contains "$PLUGIN_ROOT/engine/strategist.md" "Resolver"
}

#
# Main
#

main() {
    echo "=============================================="
    echo "  AGI-Like Interface v4.0 Integration Tests"
    echo "=============================================="
    echo ""
    echo "Plugin root: $PLUGIN_ROOT"

    # Run all test suites
    test_bin_scripts
    test_scripts
    test_commands
    test_engine_skills
    test_execution_skills
    test_memory_skills
    test_hooks
    test_schemas
    test_plugin_manifest
    test_intent_flow

    # Summary
    echo ""
    echo "=============================================="
    echo "  Test Summary"
    echo "=============================================="
    echo ""
    echo -e "  Total:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    else
        echo -e "  Failed: 0"
    fi
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

main "$@"
