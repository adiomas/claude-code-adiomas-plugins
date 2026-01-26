#!/usr/bin/env bash
# request-handoff.sh - Signal orchestrator to start new session
# Called when Claude session approaches token limit (80%)
#
# Usage:
#   ./request-handoff.sh                    # Request handoff
#   ./request-handoff.sh --reason "message" # With custom reason
#
# Version: 4.0.0

set -euo pipefail

# Configuration
readonly STATE_DIR=".claude/auto-execution"
readonly HANDOFF_SIGNAL="$STATE_DIR/.handoff-requested"
readonly STATE_FILE="$STATE_DIR/state.yaml"
readonly LOG_FILE="$STATE_DIR/orchestrator.log"

# Colors
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m'

# Logging
log() {
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [HANDOFF] $msg" >> "$LOG_FILE"
}

# Parse arguments
reason="token_limit"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --reason|-r)
            reason="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Create state directory if needed
mkdir -p "$STATE_DIR"

# Create handoff signal file with metadata
cat > "$HANDOFF_SIGNAL" << EOF
timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
reason: $reason
pid: $$
EOF

log "Handoff requested: $reason"

# Update state file if it exists
if [[ -f "$STATE_FILE" ]]; then
    # Simple update using sed
    sed -i.bak "s/^status:.*/status: \"handoff_pending\"/" "$STATE_FILE" 2>/dev/null || true
    rm -f "$STATE_FILE.bak"
fi

echo -e "${YELLOW}→ Handoff requested. New session will start shortly...${NC}"
echo -e "${GREEN}  Reason: $reason${NC}"

exit 0
