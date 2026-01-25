# AGI-Like Interface Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transformirati autonomous-dev plugin iz 10 komandi u AGI-like sučelje s jednom `/do` komandom i external orchestratorom za pravu autonomiju.

**Architecture:** External Orchestrator (`claude-agi`) + Intent Engine (Parser→Enricher→Classifier→Resolver→Strategist→Executor) + Hybrid Memory System (local/global) + Adaptive Execution (DIRECT/ORCHESTRATED) + Checkpoint System.

**Tech Stack:** Bash orchestrator, Claude Code Plugin System, YAML/JSON state files, Bash hooks, Markdown skills.

---

## Phase 0: External Orchestrator (Prerequisites)

### Task 0.1: Create claude-agi orchestrator script

**Files:**
- Create: `autonomous-dev/bin/claude-agi`

**Step 1: Create orchestrator script**

```bash
#!/bin/bash
#
# claude-agi - External orchestrator for AGI-like autonomous execution
#
# Usage: claude-agi "your task in natural language"
#        claude-agi --overnight "complex task"
#        claude-agi --continue (resume from checkpoint)
#
# This script manages Claude Code sessions, handling:
# - Automatic session restarts on handoff
# - Checkpoint-based continuity
# - Token limit detection
# - Graceful completion detection
#

set -e

# Configuration
MAX_SESSIONS="${CLAUDE_AGI_MAX_SESSIONS:-20}"
SESSION_TIMEOUT="${CLAUDE_AGI_TIMEOUT:-3600}"  # 1 hour default
STATE_FILE=".claude/state.json"
HANDOFF_SIGNAL=".claude/handoff-requested"
NEXT_SESSION_FILE=".claude/auto-execution/next-session.md"
LOG_FILE=".claude/orchestrator.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# State
SESSION_COUNT=0
OVERNIGHT_MODE=false
CONTINUE_MODE=false
INITIAL_TASK=""

#######################################
# Logging
#######################################
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    case "$level" in
        INFO)  echo -e "${BLUE}ℹ${NC} $message" ;;
        OK)    echo -e "${GREEN}✓${NC} $message" ;;
        WARN)  echo -e "${YELLOW}⚠${NC} $message" ;;
        ERROR) echo -e "${RED}✗${NC} $message" ;;
    esac
}

#######################################
# Parse arguments
#######################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --overnight)
                OVERNIGHT_MODE=true
                shift
                ;;
            --continue)
                CONTINUE_MODE=true
                shift
                ;;
            --max-sessions)
                MAX_SESSIONS="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                INITIAL_TASK="$1"
                shift
                ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
claude-agi - AGI-like autonomous execution orchestrator

USAGE:
    claude-agi "your task description"
    claude-agi --overnight "complex multi-session task"
    claude-agi --continue

OPTIONS:
    --overnight      Run in overnight mode (no prompts, auto-restart)
    --continue       Resume from last checkpoint
    --max-sessions N Maximum number of sessions (default: 20)
    --help, -h       Show this help

EXAMPLES:
    claude-agi "Add dark mode with system preference detection"
    claude-agi --overnight "Implement complete authentication system"
    claude-agi --continue

ENVIRONMENT:
    CLAUDE_AGI_MAX_SESSIONS  Maximum sessions (default: 20)
    CLAUDE_AGI_TIMEOUT       Session timeout in seconds (default: 3600)

EOF
}

#######################################
# State management
#######################################
init_state() {
    mkdir -p .claude/auto-execution
    mkdir -p "$(dirname "$LOG_FILE")"

    cat > "$STATE_FILE" << EOF
{
  "version": "2.0",
  "orchestrator": {
    "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "session_count": 0,
    "overnight_mode": $OVERNIGHT_MODE
  },
  "task": {
    "input": "$INITIAL_TASK",
    "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "execution": {
    "status": "starting",
    "current_phase": 0,
    "phases": []
  },
  "context": {
    "tokens_used": 0,
    "checkpoint_ready": false
  },
  "recovery": {
    "can_resume": true
  }
}
EOF

    log INFO "State initialized"
}

get_status() {
    if [ -f "$STATE_FILE" ]; then
        jq -r '.execution.status // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown"
    else
        echo "not_started"
    fi
}

update_status() {
    local status="$1"
    if [ -f "$STATE_FILE" ]; then
        jq ".execution.status = \"$status\"" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    fi
}

increment_session_count() {
    SESSION_COUNT=$((SESSION_COUNT + 1))
    if [ -f "$STATE_FILE" ]; then
        jq ".orchestrator.session_count = $SESSION_COUNT" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    fi
}

#######################################
# Session management
#######################################
build_session_prompt() {
    local prompt=""

    if [ "$CONTINUE_MODE" = true ] || [ $SESSION_COUNT -gt 0 ]; then
        # Continuing from checkpoint
        if [ -f "$NEXT_SESSION_FILE" ]; then
            prompt=$(cat "$NEXT_SESSION_FILE")
            prompt="$prompt

---
CONTINUE EXECUTION. Read state.json and resume from checkpoint."
        else
            prompt="Resume task from .claude/state.json checkpoint."
        fi
    else
        # Fresh start
        prompt="/do $INITIAL_TASK"
    fi

    echo "$prompt"
}

run_session() {
    increment_session_count
    log INFO "Starting session $SESSION_COUNT / $MAX_SESSIONS"

    local prompt=$(build_session_prompt)
    local claude_args=()

    # Build arguments
    if [ "$OVERNIGHT_MODE" = true ]; then
        claude_args+=("--dangerously-skip-permissions")
    fi

    claude_args+=("--print" "$prompt")

    # Clear handoff signal
    rm -f "$HANDOFF_SIGNAL"

    # Run Claude Code
    update_status "running"

    if timeout "$SESSION_TIMEOUT" claude "${claude_args[@]}"; then
        log OK "Session $SESSION_COUNT completed normally"
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log WARN "Session $SESSION_COUNT timed out"
        else
            log WARN "Session $SESSION_COUNT exited with code $exit_code"
        fi
        return $exit_code
    fi
}

check_completion() {
    local status=$(get_status)

    case "$status" in
        "done"|"completed")
            return 0  # Task is done
            ;;
        "failed")
            return 2  # Task failed
            ;;
        *)
            return 1  # Not done, continue
            ;;
    esac
}

check_handoff_requested() {
    if [ -f "$HANDOFF_SIGNAL" ]; then
        log INFO "Handoff signal detected"
        rm -f "$HANDOFF_SIGNAL"
        return 0
    fi
    return 1
}

#######################################
# Main orchestration loop
#######################################
run_orchestration() {
    log INFO "Starting AGI orchestration"
    log INFO "Task: $INITIAL_TASK"
    log INFO "Mode: $([ "$OVERNIGHT_MODE" = true ] && echo 'overnight' || echo 'interactive')"
    log INFO "Max sessions: $MAX_SESSIONS"

    # Initialize if fresh start
    if [ "$CONTINUE_MODE" != true ]; then
        init_state
    fi

    # Main loop
    while [ $SESSION_COUNT -lt $MAX_SESSIONS ]; do
        run_session

        # Check if task is complete
        if check_completion; then
            local status=$(get_status)
            if [ "$status" = "done" ] || [ "$status" = "completed" ]; then
                log OK "Task completed successfully!"
                show_completion_summary
                return 0
            else
                log ERROR "Task failed"
                show_failure_summary
                return 1
            fi
        fi

        # Check for handoff request
        if check_handoff_requested; then
            log INFO "Handoff requested, starting new session in 3 seconds..."
            sleep 3
            continue
        fi

        # Unexpected exit - ask what to do in interactive mode
        if [ "$OVERNIGHT_MODE" != true ]; then
            echo ""
            log WARN "Session ended unexpectedly"
            read -p "Continue with new session? [Y/n] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]?$ ]]; then
                log INFO "User cancelled"
                return 1
            fi
        else
            # Overnight mode - auto continue
            log INFO "Auto-continuing in overnight mode..."
            sleep 5
        fi
    done

    log ERROR "Max sessions ($MAX_SESSIONS) reached without completion"
    return 1
}

show_completion_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e " ${GREEN}✓ TASK COMPLETED${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo " Sessions used: $SESSION_COUNT"
    echo " State file: $STATE_FILE"
    echo ""

    if [ -f "$STATE_FILE" ]; then
        echo " Evidence:"
        jq -r '.evidence | to_entries[] | "   • \(.key): \(.value.proof)"' "$STATE_FILE" 2>/dev/null || true
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
}

show_failure_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e " ${RED}✗ TASK FAILED${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo " Sessions used: $SESSION_COUNT"
    echo " State file: $STATE_FILE"
    echo " Log file: $LOG_FILE"
    echo ""
    echo " To resume: claude-agi --continue"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
}

#######################################
# Entry point
#######################################
main() {
    parse_args "$@"

    # Validate
    if [ -z "$INITIAL_TASK" ] && [ "$CONTINUE_MODE" != true ]; then
        echo "Error: No task provided"
        echo "Usage: claude-agi \"your task\" or claude-agi --continue"
        exit 1
    fi

    # Check for existing state if not continuing
    if [ "$CONTINUE_MODE" != true ] && [ -f "$STATE_FILE" ]; then
        local status=$(get_status)
        if [ "$status" != "done" ] && [ "$status" != "failed" ]; then
            log WARN "Existing incomplete task found"
            read -p "Resume existing task? [Y/n] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]?$ ]]; then
                CONTINUE_MODE=true
            fi
        fi
    fi

    run_orchestration
}

main "$@"
```

**Step 2: Make executable and commit**

```bash
chmod +x autonomous-dev/bin/claude-agi
git add autonomous-dev/bin/claude-agi
git commit -m "feat: add claude-agi external orchestrator for autonomous execution"
```

---

### Task 0.2: Create handoff integration in /do command

**Files:**
- Create: `autonomous-dev/scripts/request-handoff.sh`

**Step 1: Create handoff request script**

```bash
#!/bin/bash
# request-handoff.sh - Signal orchestrator to start new session

HANDOFF_SIGNAL=".claude/handoff-requested"
STATE_FILE=".claude/state.json"
NEXT_SESSION=".claude/auto-execution/next-session.md"

request_handoff() {
    local reason="${1:-token_limit}"
    local checkpoint_id="${2:-$(date +%Y%m%d-%H%M%S)}"

    # Update state
    jq ".execution.status = \"handoff\" | .recovery.last_checkpoint = \"$checkpoint_id\"" \
        "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

    # Create handoff signal
    echo "$reason" > "$HANDOFF_SIGNAL"

    # Log
    echo "Handoff requested: $reason (checkpoint: $checkpoint_id)"
}

case "$1" in
    request) request_handoff "$2" "$3" ;;
    *) echo "Usage: request-handoff.sh request [reason] [checkpoint_id]" ;;
esac
```

**Step 2: Commit**

```bash
chmod +x autonomous-dev/scripts/request-handoff.sh
git add autonomous-dev/scripts/request-handoff.sh
git commit -m "feat: add handoff request script for orchestrator integration"
```

---

### Task 0.3: Create installation script

**Files:**
- Create: `autonomous-dev/bin/install-claude-agi.sh`

**Step 1: Create installer**

```bash
#!/bin/bash
# install-claude-agi.sh - Install claude-agi to user's PATH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"

echo "Installing claude-agi..."

# Create install directory
mkdir -p "$INSTALL_DIR"

# Copy or symlink
if [ "$1" = "--link" ]; then
    ln -sf "$SCRIPT_DIR/claude-agi" "$INSTALL_DIR/claude-agi"
    echo "Symlinked claude-agi to $INSTALL_DIR"
else
    cp "$SCRIPT_DIR/claude-agi" "$INSTALL_DIR/claude-agi"
    chmod +x "$INSTALL_DIR/claude-agi"
    echo "Copied claude-agi to $INSTALL_DIR"
fi

# Check PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "⚠️  $INSTALL_DIR is not in your PATH"
    echo "Add this to your ~/.bashrc or ~/.zshrc:"
    echo ""
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

echo ""
echo "✓ Installation complete!"
echo ""
echo "Usage:"
echo "    claude-agi \"your task\""
echo "    claude-agi --overnight \"complex task\""
echo "    claude-agi --continue"
```

**Step 2: Commit**

```bash
chmod +x autonomous-dev/bin/install-claude-agi.sh
git add autonomous-dev/bin/install-claude-agi.sh
git commit -m "feat: add claude-agi installer script"
```

---

## Phase 1: Foundation (Commands + State)

### Task 1.1: Create /do command skeleton

**Files:**
- Create: `autonomous-dev/commands/do.md`

**Step 1: Create command**

```markdown
---
name: do
description: >
  AGI-like unified command. Understands natural language,
  automatically selects execution strategy, learns from experience.
  Replaces: /auto, /auto-smart, /auto-lite, /auto-prepare, /auto-execute
arguments: "<task description in natural language>"
---

# /do - Unified AGI-Like Command

## Overview

Jedna komanda koja razumije bilo koji zahtjev na prirodnom jeziku i automatski:
1. Parsira intent
2. Obogaćuje kontekstom iz memorije
3. Klasificira tip i kompleksnost
4. Rješava nejasnoće (pita samo ako kritično)
5. Odabire strategiju (DIRECT/ORCHESTRATED)
6. Izvršava s TDD i verifikacijom
7. Uči iz iskustva

## Invocation

```
/do <bilo što na prirodnom jeziku>
```

**Primjeri:**
- `/do Napravi dark mode`
- `/do Popravi bug u login formi`
- `/do Ono od jučer ne radi`
- `/do Zašto je API spor?`

## Protocol

### Step 1: Initialize State

```bash
scripts/state-manager.sh init "$USER_INPUT" "UNKNOWN" 0
```

### Step 2: Parse Intent

Invoke: `autonomous-dev:intent-parser`

Extract:
- Intent type (FEATURE, BUG_FIX, REFACTOR, RESEARCH, QUESTION)
- References ("ono", "jučer", etc.)
- Sub-tasks (if composite)
- Keywords and entities

### Step 3: Enrich with Memory

Invoke: `autonomous-dev:memory-enricher`

Load:
- Project context (stack, quirks)
- Local memory (recent work, project learnings)
- Global memory (patterns, gotchas, preferences)
- Similar past tasks

### Step 4: Classify

Invoke: `autonomous-dev:intent-classifier`

Determine:
- Final intent type
- Complexity score (1-5)
- Work type (FRONTEND/BACKEND/FULLSTACK)

### Step 5: Resolve Ambiguity

Invoke: `autonomous-dev:intent-resolver`

Check:
- Confidence level (if <70% → clarify)
- Critical actions (deletion, security, database → MUST ask)
- References resolved?

**If needs clarification:**
- If 2-3 interpretations → offer choices
- If more → ask open question

**If critical action:**
- Always ask for confirmation

### Step 6: Select Strategy

Based on complexity:
- **1-2:** DIRECT mode (simple loop, no checkpoints)
- **3-5:** ORCHESTRATED mode (phases, TDD, checkpoints)

### Step 7: Execute

**DIRECT Mode:**
```
1. Quick plan (internal)
2. Implement
3. Verify
4. Done
```

**ORCHESTRATED Mode:**
```
For each phase:
  1. Checkpoint(start)
  2. TDD: Write test → Implement → Refactor
  3. Verify phase
  4. Checkpoint(complete)
Final verification
```

### Step 8: Monitor Tokens

At 80% token usage:
1. Create checkpoint
2. Write next-session.md
3. Request handoff: `scripts/request-handoff.sh request token_limit`

### Step 9: Learn

On success, invoke: `autonomous-dev:learning-extractor`

Extract and store:
- Patterns that worked → global memory
- Project quirks → local memory
- Gotchas encountered → appropriate memory

### Step 10: Complete

Output summary:
```
✓ Gotovo.

  Kreirano:
  • file1.ts
  • file2.ts

  Verificirano:
  • Tests: 8/8 passing
  • Build: success

  Commit? [Da] [Ne]
```

## Handoff Protocol

When token limit approaching:

1. **At 70%:** Start context compression
2. **At 80%:**
   - Complete current phase if possible
   - Create full checkpoint
   - Write next-session.md
   - Signal handoff
   - Exit gracefully

Orchestrator (`claude-agi`) will:
1. Detect handoff signal
2. Start new session
3. New session reads next-session.md
4. Continues from checkpoint

## State File

All state in `.claude/state.json`:

```json
{
  "version": "2.0",
  "task": { "input": "...", "intent": "...", "complexity": N },
  "execution": { "strategy": "...", "status": "...", "phases": [...] },
  "evidence": { "phase-1": { "claim": "...", "proof": "..." } },
  "context": { "tokens_used": N, "key_decisions": [...] },
  "recovery": { "can_resume": true, "resume_from": "..." }
}
```

## Flags

- `--continue` - Resume from checkpoint
- `--overnight` - No prompts, auto-approve (use with claude-agi)

## Related Commands

- `/status` - Check execution progress
- `/cancel` - Cancel and cleanup
```

**Step 2: Commit**

```bash
git add autonomous-dev/commands/do.md
git commit -m "feat: add /do unified AGI-like command"
```

---

### Task 1.2: Create unified state schema and manager

**Files:**
- Create: `autonomous-dev/schemas/state.schema.json`
- Create: `autonomous-dev/scripts/state-manager.sh`

*(Content as in previous Task 2)*

---

### Task 1.3: Create /status command

**Files:**
- Create: `autonomous-dev/commands/status.md`

**Step 1: Create command**

```markdown
---
name: status
description: Check progress of current /do execution
---

# /status - Check Execution Progress

## Protocol

1. Read `.claude/state.json`
2. Display progress summary
3. Show evidence collected

## Output Format

```
📊 Status: [running|paused|done|failed]

Task: "{original input}"
Mode: [DIRECT|ORCHESTRATED]
Progress: {completed}/{total} phases ({percentage}%)

Completed:
✓ Phase 1: {name} [{evidence}]
✓ Phase 2: {name} [{evidence}]

In Progress:
→ Phase 3: {name}

Pending:
○ Phase 4: {name}

Tokens: {used}/{budget} ({percentage}%)
Last checkpoint: {timestamp}
```
```

**Step 2: Commit**

```bash
git add autonomous-dev/commands/status.md
git commit -m "feat: add /status command"
```

---

### Task 1.4: Create /cancel command

**Files:**
- Create: `autonomous-dev/commands/cancel.md`

*(Similar structure - cancels execution, cleans up)*

---

## Phase 2: Intent Engine

### Task 2.1: Create Intent Parser skill

**Files:**
- Create: `autonomous-dev/engine/parser.md`

### Task 2.2: Create Intent Enricher skill

**Files:**
- Create: `autonomous-dev/engine/enricher.md`

### Task 2.3: Create Intent Classifier skill

**Files:**
- Create: `autonomous-dev/engine/classifier.md`

### Task 2.4: Create Intent Resolver skill

**Files:**
- Create: `autonomous-dev/engine/resolver.md`

### Task 2.5: Create Execution Strategist skill

**Files:**
- Create: `autonomous-dev/engine/strategist.md`

---

## Phase 3: Memory System

### Task 3.1: Create Local Memory Manager

**Files:**
- Create: `autonomous-dev/memory/local-manager.md`
- Create: `autonomous-dev/scripts/local-memory.sh`

### Task 3.2: Create Global Memory Manager

**Files:**
- Create: `autonomous-dev/memory/global-manager.md`
- Create: `autonomous-dev/scripts/global-memory.sh`

### Task 3.3: Create Learning Extractor

**Files:**
- Create: `autonomous-dev/memory/learner.md`
- Create: `autonomous-dev/scripts/extract-learnings.sh`

### Task 3.4: Create Forgetter (cleanup)

**Files:**
- Create: `autonomous-dev/memory/forgetter.md`
- Create: `autonomous-dev/scripts/memory-cleanup.sh`

---

## Phase 4: Execution Engine

### Task 4.1: Create Direct Executor

**Files:**
- Create: `autonomous-dev/execution/direct-executor.md`

### Task 4.2: Create Orchestrated Executor

**Files:**
- Create: `autonomous-dev/execution/orchestrated-executor.md`

### Task 4.3: Create Checkpoint Manager skill

**Files:**
- Create: `autonomous-dev/execution/checkpoint-manager.md`
- Modify: `autonomous-dev/scripts/checkpoint-manager.sh`

### Task 4.4: Create Failure Handler

**Files:**
- Create: `autonomous-dev/execution/failure-handler.md`

### Task 4.5: Create Handoff Manager

**Files:**
- Create: `autonomous-dev/execution/handoff-manager.md`

### Task 4.6: Create TDD Executor

**Files:**
- Create: `autonomous-dev/execution/tdd-executor.md`

---

## Phase 5: Integration

### Task 5.1: Update hooks.json

**Files:**
- Modify: `autonomous-dev/hooks/hooks.json`

### Task 5.2: Create session-end hook for learning

**Files:**
- Create: `autonomous-dev/hooks/session-end-learning.sh`

### Task 5.3: Update plugin manifest

**Files:**
- Modify: `autonomous-dev/.claude-plugin/plugin.json`

### Task 5.4: Deprecate old commands (soft)

**Files:**
- Modify: `autonomous-dev/commands/auto.md` (add deprecation notice)
- Modify: `autonomous-dev/commands/auto-smart.md`
- Modify: `autonomous-dev/commands/auto-lite.md`
- (etc.)

---

## Phase 6: Testing & Documentation

### Task 6.1: Create integration test

**Files:**
- Create: `autonomous-dev/tests/test-do-command.sh`

### Task 6.2: Update README

**Files:**
- Modify: `autonomous-dev/README.md`

### Task 6.3: Create migration guide

**Files:**
- Create: `autonomous-dev/docs/migration-v4.md`

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 0. Orchestrator | 0.1-0.3 | `claude-agi` external orchestrator |
| 1. Foundation | 1.1-1.4 | /do, /status, /cancel + unified state |
| 2. Intent Engine | 2.1-2.5 | Parser, Enricher, Classifier, Resolver, Strategist |
| 3. Memory System | 3.1-3.4 | Local, Global, Learner, Forgetter |
| 4. Execution | 4.1-4.6 | Direct, Orchestrated, Checkpoint, Failure, Handoff, TDD |
| 5. Integration | 5.1-5.4 | Hooks, manifest, deprecation |
| 6. Testing | 6.1-6.3 | Tests, docs, migration |

**Total: 27 tasks in 7 phases**

---

## Execution Strategy

**Parallel Groups:**
- Group 1: Tasks 0.1, 0.2, 0.3 (orchestrator) - independent
- Group 2: Tasks 1.1-1.4 (foundation) - after Group 1
- Group 3: Tasks 2.1-2.5 (intent engine) - can parallel with Group 4
- Group 4: Tasks 3.1-3.4 (memory) - can parallel with Group 3
- Group 5: Tasks 4.1-4.6 (execution) - after Groups 3,4
- Group 6: Tasks 5.1-5.4 (integration) - after Group 5
- Group 7: Tasks 6.1-6.3 (testing) - after Group 6

**Verification:**
- Test command: `./autonomous-dev/tests/run-all-tests.sh`
- Lint: N/A (markdown/bash)
- Build: N/A (plugin, no build)
