---
name: cancel
description: Cancel autonomous execution and clean up state
argument-hint: "[--force] [--discard]"
allowed-tools: ["Bash", "Read", "Write"]
---

# /cancel - Cancel Execution and Cleanup

Stops the current autonomous execution and cleans up state.

```
/cancel
```

## What It Does

1. **Stops orchestrator** if running
2. **Creates checkpoint** of current progress
3. **Updates state** to cancelled
4. **Cleans up** temporary files
5. **Shows summary** of what was completed

## Output

```
═══════════════════════════════════════════════════════════════════
 Cancelling Execution
═══════════════════════════════════════════════════════════════════

 ⚠ Stopping autonomous execution...

 Progress preserved:
 ✓ Phase 1: ThemeProvider [completed]
 ✓ Phase 2: useTheme hook [completed]
 ○ Phase 3: Toggle component [cancelled]
 ○ Phase 4: Integration [not started]

 Checkpoint: chk-20250126-153000

 To resume later: /do --continue

 Cleanup:
 • Orchestrator stopped
 • Temporary files removed
 • State updated to cancelled

═══════════════════════════════════════════════════════════════════
```

## Confirmation

For safety, asks for confirmation:

```
⚠ Cancel autonomous execution?

Current progress: Phase 2 of 4 (50%)
Uncommitted changes: 3 files modified

[Cancel & Save Progress] [Cancel & Discard] [Continue Execution]
```

## Options

```
/cancel              # Cancel with confirmation
/cancel --force      # Cancel immediately without confirmation
/cancel --discard    # Cancel and discard all changes
```

## No Active Execution

```
Nothing to cancel - no active execution.
```

## Implementation

Uses:
- `bin/claude-agi --cancel` - Stop orchestrator
- `scripts/state-manager.sh` - Update state
- `scripts/checkpoint-manager.sh` - Save checkpoint

Cleanup steps:
1. Kill orchestrator PID if exists
2. Remove `.claude/auto-execution/.handoff-requested`
3. Remove `.claude/auto-execution/.claude-agi.pid`
4. Update `state.yaml` status to "cancelled"
5. Commit progress if any (optional)
