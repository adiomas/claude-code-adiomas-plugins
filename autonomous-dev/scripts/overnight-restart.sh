#!/bin/bash
# overnight-restart.sh
# Triggered when context limit reached during overnight mode
# Restarts Claude Code with /auto-continue and full autonomy

set -e

STATE_FILE=".claude/auto-overnight.local.md"
LOG_DIR=".claude/overnight-logs"
MEMORY_DIR=".claude/auto-memory"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[overnight-restart]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[overnight-restart]${NC} $1"
}

error() {
    echo -e "${RED}[overnight-restart]${NC} $1" >&2
}

# Check if overnight mode is active
if [[ ! -f "$STATE_FILE" ]]; then
    error "Overnight state file not found: $STATE_FILE"
    exit 1
fi

# Check if overnight mode is still active
ACTIVE=$(grep "^active:" "$STATE_FILE" | cut -d' ' -f2 | tr -d ' ')
if [[ "$ACTIVE" != "true" ]]; then
    log "Overnight mode is not active. Exiting."
    exit 0
fi

# Create directories if needed
mkdir -p "$LOG_DIR"
mkdir -p "$MEMORY_DIR"

# Read current iteration
ITERATION=$(grep "^iteration:" "$STATE_FILE" | cut -d' ' -f2 | tr -d ' ')
if [[ -z "$ITERATION" ]] || ! [[ "$ITERATION" =~ ^[0-9]+$ ]]; then
    warn "Invalid iteration value, defaulting to 1"
    ITERATION=1
fi

# Read max iterations
MAX_ITERATIONS=$(grep "^max_iterations:" "$STATE_FILE" | cut -d' ' -f2 | tr -d ' ')
if [[ -z "$MAX_ITERATIONS" ]] || ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
    MAX_ITERATIONS=500
fi

# Check if we've hit max iterations
if [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
    log "Max iterations ($MAX_ITERATIONS) reached. Stopping overnight mode."
    sed -i '' 's/^active: true/active: false/' "$STATE_FILE"
    exit 0
fi

# Check deadline
DEADLINE=$(grep "^deadline_at:" "$STATE_FILE" | cut -d'"' -f2)
if [[ -n "$DEADLINE" ]]; then
    DEADLINE_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$DEADLINE" "+%s" 2>/dev/null || date -d "$DEADLINE" "+%s" 2>/dev/null || echo "0")
    NOW_EPOCH=$(date "+%s")

    if [[ $NOW_EPOCH -ge $DEADLINE_EPOCH ]] && [[ $DEADLINE_EPOCH -gt 0 ]]; then
        log "Deadline reached. Stopping overnight mode."
        sed -i '' 's/^active: true/active: false/' "$STATE_FILE"
        exit 0
    fi
fi

# Increment iteration
NEW_ITERATION=$((ITERATION + 1))
log "Incrementing iteration: $ITERATION -> $NEW_ITERATION"

# Update state file (macOS compatible)
if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/^iteration: .*/iteration: $NEW_ITERATION/" "$STATE_FILE"
else
    sed -i "s/^iteration: .*/iteration: $NEW_ITERATION/" "$STATE_FILE"
fi

# Update checkpoint timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/^last_checkpoint: .*/last_checkpoint: \"$TIMESTAMP\"/" "$STATE_FILE"
else
    sed -i "s/^last_checkpoint: .*/last_checkpoint: \"$TIMESTAMP\"/" "$STATE_FILE"
fi

# Create checkpoint summary for new session
cat > "$MEMORY_DIR/overnight-checkpoint.md" << EOF
# Overnight Checkpoint

## Session Info
- **Iteration:** $NEW_ITERATION of $MAX_ITERATIONS
- **Timestamp:** $TIMESTAMP
- **Previous session ended due to:** context limit

## Instructions for New Session
1. Read .claude/auto-progress.yaml for task status
2. Read .claude/auto-overnight.local.md for overnight config
3. Continue with /auto-continue
4. Follow overnight-mode skill rules

## Important
- DO NOT ask user questions
- Continue autonomously
- Checkpoint frequently
EOF

log "Checkpoint saved to $MEMORY_DIR/overnight-checkpoint.md"

# Prepare log file for new session
SESSION_LOG="$LOG_DIR/session-$NEW_ITERATION.log"

log "Starting new overnight session (iteration $NEW_ITERATION)"
log "Log file: $SESSION_LOG"

# Start new Claude Code session with full autonomy
# Uses nohup to detach from current terminal
nohup claude -p "/auto-continue" \
    --dangerously-skip-permissions \
    > "$SESSION_LOG" 2>&1 &

NEW_PID=$!
log "Started new session with PID: $NEW_PID"

# Save PID for tracking
echo "$NEW_PID" > ".claude/overnight-pid"

log "Overnight restart complete. New session running in background."
log "Monitor with: tail -f $SESSION_LOG"

exit 0
