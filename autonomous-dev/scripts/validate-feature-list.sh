#!/usr/bin/env bash
# validate-feature-list.sh - Validates feature list YAML files
# Ensures no features start as passing and all have evidence_required: true
#
# Usage: ./validate-feature-list.sh <feature-list.yaml>
# Exit codes:
#   0 - Validation passed
#   1 - Validation failed (invalid features found)
#   2 - File not found or invalid arguments

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [[ $# -lt 1 ]]; then
    echo -e "${RED}Error: Feature list file required${NC}"
    echo "Usage: $0 <feature-list.yaml>"
    exit 2
fi

FEATURE_FILE="$1"

# Check if file exists
if [[ ! -f "$FEATURE_FILE" ]]; then
    echo -e "${RED}Error: File not found: $FEATURE_FILE${NC}"
    exit 2
fi

echo "Validating feature list: $FEATURE_FILE"
echo "================================================"

# Track validation results
ERRORS=0
WARNINGS=0

# Check for any status: passing at the start (initial state violation)
echo -e "\n${YELLOW}Checking initial status...${NC}"
PASSING_FEATURES=$(grep -n "status:\s*passing" "$FEATURE_FILE" 2>/dev/null || true)
if [[ -n "$PASSING_FEATURES" ]]; then
    echo -e "${RED}ERROR: Features found with status: passing (must start as failing)${NC}"
    echo "$PASSING_FEATURES"
    ((ERRORS++))
else
    echo -e "${GREEN}✓ All features start with correct status${NC}"
fi

# Check all features have evidence_required: true
echo -e "\n${YELLOW}Checking evidence_required...${NC}"

# Count features and evidence_required: true
FEATURE_COUNT=$(grep -c "^  - id:" "$FEATURE_FILE" 2>/dev/null || echo "0")
EVIDENCE_TRUE_COUNT=$(grep -c "evidence_required:\s*true" "$FEATURE_FILE" 2>/dev/null || echo "0")

if [[ "$FEATURE_COUNT" -eq 0 ]]; then
    echo -e "${YELLOW}Warning: No features found in file${NC}"
    ((WARNINGS++))
elif [[ "$FEATURE_COUNT" -ne "$EVIDENCE_TRUE_COUNT" ]]; then
    echo -e "${RED}ERROR: Not all features have evidence_required: true${NC}"
    echo "Features: $FEATURE_COUNT, With evidence_required: $EVIDENCE_TRUE_COUNT"

    # Find features missing evidence_required
    echo -e "\n${YELLOW}Features missing evidence_required: true:${NC}"
    # Use awk to find feature blocks without evidence_required: true
    awk '/^  - id:/{feature=$0; has_evidence=0} /evidence_required:\s*true/{has_evidence=1} /^  - id:|^$/{if(feature && !has_evidence) print feature}' "$FEATURE_FILE"

    ((ERRORS++))
else
    echo -e "${GREEN}✓ All $FEATURE_COUNT features have evidence_required: true${NC}"
fi

# Check for can_be_removed: false
echo -e "\n${YELLOW}Checking can_be_removed...${NC}"
CAN_REMOVE_TRUE=$(grep -c "can_be_removed:\s*true" "$FEATURE_FILE" 2>/dev/null | tr -d '\n' || echo "0")
if [[ "$CAN_REMOVE_TRUE" -gt 0 ]]; then
    echo -e "${YELLOW}Warning: $CAN_REMOVE_TRUE features have can_be_removed: true${NC}"
    grep -n "can_be_removed:\s*true" "$FEATURE_FILE"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓ No features can be removed${NC}"
fi

# Check that all features have verification_command
echo -e "\n${YELLOW}Checking verification commands...${NC}"
VERIFICATION_COUNT=$(grep -c "verification_command:" "$FEATURE_FILE" 2>/dev/null || echo "0")
if [[ "$FEATURE_COUNT" -gt 0 && "$FEATURE_COUNT" -ne "$VERIFICATION_COUNT" ]]; then
    echo -e "${RED}ERROR: Not all features have verification_command${NC}"
    echo "Features: $FEATURE_COUNT, With verification_command: $VERIFICATION_COUNT"
    ((ERRORS++))
else
    echo -e "${GREEN}✓ All features have verification commands${NC}"
fi

# Check that all features have expected_output
echo -e "\n${YELLOW}Checking expected output...${NC}"
EXPECTED_COUNT=$(grep -c "expected_output:" "$FEATURE_FILE" 2>/dev/null || echo "0")
if [[ "$FEATURE_COUNT" -gt 0 && "$FEATURE_COUNT" -ne "$EXPECTED_COUNT" ]]; then
    echo -e "${RED}ERROR: Not all features have expected_output${NC}"
    echo "Features: $FEATURE_COUNT, With expected_output: $EXPECTED_COUNT"
    ((ERRORS++))
else
    echo -e "${GREEN}✓ All features have expected output patterns${NC}"
fi

# Summary
echo -e "\n================================================"
echo "Validation Summary"
echo "================================================"
echo "Features checked: $FEATURE_COUNT"
echo -e "Errors: ${RED}$ERRORS${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"

if [[ $ERRORS -gt 0 ]]; then
    echo -e "\n${RED}VALIDATION FAILED${NC}"
    exit 1
else
    echo -e "\n${GREEN}VALIDATION PASSED${NC}"
    exit 0
fi
