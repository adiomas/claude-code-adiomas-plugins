#!/bin/bash
# Smart Ralph - Resume Check
# Checks for incomplete Smart Ralph sessions and offers to resume

set -e

STATE_DIR=".claude/smart-ralph"
STATE_FILE="$STATE_DIR/state.yaml"
PROGRESS_FILE="$STATE_DIR/progress.md"

# Check if state file exists
if [[ ! -f "$STATE_FILE" ]]; then
    exit 0
fi

# Read state
if command -v yq &> /dev/null; then
    PHASE=$(yq -r '.phase // "UNKNOWN"' "$STATE_FILE" 2>/dev/null || echo "UNKNOWN")
    MODE=$(yq -r '.mode // "UNKNOWN"' "$STATE_FILE" 2>/dev/null || echo "UNKNOWN")
    PROMPT=$(yq -r '.prompt // "Unknown task"' "$STATE_FILE" 2>/dev/null || echo "Unknown task")
    STARTED=$(yq -r '.started_at // "Unknown"' "$STATE_FILE" 2>/dev/null || echo "Unknown")
    SCORE=$(yq -r '.complexity.score // "?"' "$STATE_FILE" 2>/dev/null || echo "?")
else
    # Fallback to grep if yq not available
    PHASE=$(grep -E "^phase:" "$STATE_FILE" 2>/dev/null | cut -d: -f2 | tr -d ' "' || echo "UNKNOWN")
    MODE=$(grep -E "^mode:" "$STATE_FILE" 2>/dev/null | cut -d: -f2 | tr -d ' "' || echo "UNKNOWN")
    PROMPT=$(grep -E "^prompt:" "$STATE_FILE" 2>/dev/null | cut -d: -f2- | tr -d '"' | xargs || echo "Unknown task")
    STARTED=$(grep -E "^started_at:" "$STATE_FILE" 2>/dev/null | cut -d: -f2- | tr -d ' "' || echo "Unknown")
    SCORE=$(grep -E "score:" "$STATE_FILE" 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ' || echo "?")
fi

# Check if already complete
if [[ "$PHASE" == "COMPLETE" ]]; then
    exit 0
fi

# Check for stuck state
STUCK_REPORT="$STATE_DIR/stuck-report.md"
IS_STUCK="false"
if [[ -f "$STUCK_REPORT" ]]; then
    IS_STUCK="true"
fi

# Calculate time ago
if [[ "$STARTED" != "Unknown" ]] && command -v date &> /dev/null; then
    # Try to parse ISO date
    if [[ "$OSTYPE" == "darwin"* ]]; then
        START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${STARTED%%.*}" "+%s" 2>/dev/null || echo "0")
    else
        START_EPOCH=$(date -d "$STARTED" "+%s" 2>/dev/null || echo "0")
    fi
    NOW_EPOCH=$(date "+%s")

    if [[ "$START_EPOCH" != "0" ]]; then
        DIFF=$((NOW_EPOCH - START_EPOCH))
        if [[ $DIFF -lt 3600 ]]; then
            TIME_AGO="$((DIFF / 60)) minutes ago"
        elif [[ $DIFF -lt 86400 ]]; then
            TIME_AGO="$((DIFF / 3600)) hours ago"
        else
            TIME_AGO="$((DIFF / 86400)) days ago"
        fi
    else
        TIME_AGO="unknown time ago"
    fi
else
    TIME_AGO="unknown time ago"
fi

# Get phase progress for orchestrated mode
PHASE_PROGRESS=""
if [[ "$MODE" == "ORCHESTRATED" ]] && command -v yq &> /dev/null; then
    TOTAL_PHASES=$(yq -r '.orchestrated_phases | length' "$STATE_FILE" 2>/dev/null || echo "?")
    COMPLETED_PHASES=$(yq -r '[.orchestrated_phases[] | select(.status == "complete")] | length' "$STATE_FILE" 2>/dev/null || echo "0")
    PHASE_PROGRESS=" (Phase $COMPLETED_PHASES/$TOTAL_PHASES)"
fi

# Output resume prompt
if [[ "$IS_STUCK" == "true" ]]; then
    cat << EOF

<smart-ralph-resume type="stuck">
┌─────────────────────────────────────────┐
│  SMART RALPH - Stuck Session Found      │
├─────────────────────────────────────────┤
│  Task: ${PROMPT:0:35}...
│  Mode: $MODE (Complexity: $SCORE/5)
│  Status: STUCK - needs intervention
│  Last active: $TIME_AGO
│                                         │
│  See: $STUCK_REPORT
│                                         │
│  Review the stuck report for guidance   │
│  on how to proceed.                     │
└─────────────────────────────────────────┘
</smart-ralph-resume>

EOF
else
    cat << EOF

<smart-ralph-resume type="incomplete">
┌─────────────────────────────────────────┐
│  SMART RALPH - Incomplete Session       │
├─────────────────────────────────────────┤
│  Task: ${PROMPT:0:35}...
│  Mode: $MODE (Complexity: $SCORE/5)
│  Progress: $PHASE$PHASE_PROGRESS
│  Last active: $TIME_AGO
│                                         │
│  Resuming from last checkpoint...       │
└─────────────────────────────────────────┘
</smart-ralph-resume>

EOF
fi
