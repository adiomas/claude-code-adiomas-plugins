#!/bin/bash
# =============================================================================
# CHECKPOINT MANAGER v3.0
# =============================================================================
# Manages memory files and checkpoints for session resume capability.
# Implements the Ralph pattern: files as long-term memory.
# =============================================================================

set -euo pipefail

STATE_MACHINE_FILE=".claude/auto-state-machine.yaml"
MEMORY_DIR=".claude/auto-memory"
PROGRESS_FILE=".claude/auto-progress.yaml"

# =============================================================================
# MEMORY FILE TEMPLATES
# =============================================================================

create_phase_summary() {
    local phase="$1"
    local content="$2"
    local file="$MEMORY_DIR/phase-${phase,,}-summary.md"

    mkdir -p "$MEMORY_DIR"

    cat > "$file" << EOF
# Phase $phase Summary
Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Key Decisions
$content

## Files Created/Modified
$(git diff --name-only HEAD~1 2>/dev/null || echo "- No git changes tracked")

---
EOF

    echo "Summary created: $file"
}

create_task_learning() {
    local task_id="$1"
    local learning="$2"
    local file="$MEMORY_DIR/task-${task_id}-learnings.md"

    mkdir -p "$MEMORY_DIR"

    cat > "$file" << EOF
# Task $task_id Learnings
Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## What Was Done
$learning

## Verification Results
- Tests: $(yq -r ".tasks[\"$task_id\"].test_result // \"unknown\"" "$PROGRESS_FILE" 2>/dev/null || echo "unknown")
- Iterations: $(yq -r ".tasks[\"$task_id\"].iterations // 0" "$PROGRESS_FILE" 2>/dev/null || echo "0")

---
EOF

    echo "Learning created: $file"
}

create_context_summary() {
    local file="$MEMORY_DIR/context-summary.md"

    mkdir -p "$MEMORY_DIR"

    # Gather information from state machine
    local state work_type session_id completed focus
    state=$(yq -r '.current_state // "IDLE"' "$STATE_MACHINE_FILE" 2>/dev/null || echo "IDLE")
    work_type=$(yq -r '.work_type // ""' "$STATE_MACHINE_FILE" 2>/dev/null || echo "")
    session_id=$(yq -r '.session_id // ""' "$STATE_MACHINE_FILE" 2>/dev/null || echo "")
    completed=$(yq -r '.completed_phases | join(", ")' "$STATE_MACHINE_FILE" 2>/dev/null || echo "")
    focus=$(yq -r '.focus | join(", ")' "$STATE_MACHINE_FILE" 2>/dev/null || echo "")

    # Get plan file if exists
    local plan_file plan_summary
    plan_file=$(ls -t .claude/plans/auto-*.md 2>/dev/null | head -1 || echo "")
    if [[ -n "$plan_file" ]]; then
        plan_summary=$(head -50 "$plan_file" 2>/dev/null || echo "")
    else
        plan_summary="No plan file found"
    fi

    cat > "$file" << EOF
# Context Summary for Resume
Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Session: $session_id

## Current State
- **Phase:** $state
- **Work Type:** $work_type
- **Focus:** $focus
- **Completed Phases:** $completed

## Plan Summary
\`\`\`
$plan_summary
\`\`\`

## Recent Progress
$(tail -20 "$PROGRESS_FILE" 2>/dev/null || echo "No progress file")

## Memory Files Available
$(ls -1 "$MEMORY_DIR" 2>/dev/null | grep -v context-summary.md || echo "None")

## Next Actions
Read the plan file and continue from current phase.
If EXECUTE phase: Check which tasks are pending in auto-progress.yaml
If REVIEW phase: Run fresh verification

---
EOF

    echo "Context summary created: $file"
}

# =============================================================================
# CHECKPOINT OPERATIONS
# =============================================================================

write_checkpoint() {
    local phase="$1"
    local summary="$2"

    # Create phase summary
    create_phase_summary "$phase" "$summary"

    # Update state machine with checkpoint
    if [[ -f "$STATE_MACHINE_FILE" ]]; then
        yq -i ".checkpoint_files += [\"$MEMORY_DIR/phase-${phase,,}-summary.md\"]" "$STATE_MACHINE_FILE"
        yq -i ".last_checkpoint = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$STATE_MACHINE_FILE"
    fi

    # Create/update context summary
    create_context_summary

    echo "Checkpoint written for phase: $phase"
}

read_checkpoint() {
    if [[ ! -d "$MEMORY_DIR" ]]; then
        echo "NO_CHECKPOINTS"
        return 1
    fi

    echo "=== RESUME CONTEXT ==="
    echo ""

    # Read context summary first
    if [[ -f "$MEMORY_DIR/context-summary.md" ]]; then
        echo "### Context Summary ###"
        cat "$MEMORY_DIR/context-summary.md"
        echo ""
    fi

    # List other memory files
    echo "### Available Memory Files ###"
    for f in "$MEMORY_DIR"/*.md; do
        if [[ -f "$f" && "$(basename "$f")" != "context-summary.md" ]]; then
            echo "- $f"
        fi
    done

    echo ""
    echo "=== END RESUME CONTEXT ==="
}

prepare_handoff() {
    # Called when token limit is approaching
    # Creates complete state dump for next session

    echo "Preparing session handoff..."

    # Create comprehensive context summary
    create_context_summary

    # Write next actions file
    local next_actions_file="$MEMORY_DIR/next-actions.md"
    local state
    state=$(yq -r '.current_state // "IDLE"' "$STATE_MACHINE_FILE" 2>/dev/null || echo "IDLE")

    cat > "$next_actions_file" << EOF
# Next Actions for Resume
Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Immediate Actions
1. Run \`/auto-continue\` to resume session
2. Read context-summary.md for current state
3. Continue from phase: $state

## Do NOT
- Do not re-run planning phase (already complete)
- Do not re-detect project (profile exists)
- Do not re-classify work type (already set)

## Files to Read
1. .claude/auto-state-machine.yaml - Current state
2. .claude/auto-memory/context-summary.md - Full context
3. .claude/plans/auto-*.md - Execution plan

---
EOF

    echo "Handoff prepared. Run /auto-continue in new session."
}

cleanup() {
    # Clean up memory files after successful completion

    if [[ -d "$MEMORY_DIR" ]]; then
        # Archive instead of delete
        local archive="$MEMORY_DIR/archive-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$archive"
        mv "$MEMORY_DIR"/*.md "$archive/" 2>/dev/null || true
        echo "Memory files archived to: $archive"
    fi
}

# =============================================================================
# MAIN COMMAND HANDLER
# =============================================================================

case "${1:-help}" in
    "write")
        if [[ -z "${2:-}" || -z "${3:-}" ]]; then
            echo "Usage: $0 write <phase> <summary>" >&2
            exit 1
        fi
        write_checkpoint "$2" "$3"
        ;;
    "read")
        read_checkpoint
        ;;
    "task")
        if [[ -z "${2:-}" || -z "${3:-}" ]]; then
            echo "Usage: $0 task <task_id> <learning>" >&2
            exit 1
        fi
        create_task_learning "$2" "$3"
        ;;
    "context")
        create_context_summary
        ;;
    "handoff")
        prepare_handoff
        ;;
    "cleanup")
        cleanup
        ;;
    "help"|*)
        cat << 'EOF'
Checkpoint Manager v3.0

Usage:
  checkpoint-manager.sh write <phase> <summary>    Write phase checkpoint
  checkpoint-manager.sh read                       Read all checkpoints for resume
  checkpoint-manager.sh task <id> <learning>       Record task learnings
  checkpoint-manager.sh context                    Create context summary
  checkpoint-manager.sh handoff                    Prepare for session handoff
  checkpoint-manager.sh cleanup                    Archive memory files

Memory Files Created:
  .claude/auto-memory/phase-*-summary.md     Phase summaries
  .claude/auto-memory/task-*-learnings.md    Task learnings
  .claude/auto-memory/context-summary.md     Full context for resume
  .claude/auto-memory/next-actions.md        Handoff instructions
EOF
        ;;
esac
