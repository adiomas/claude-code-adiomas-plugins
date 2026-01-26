---
name: status
description: Check progress of autonomous execution
allowed-tools: ["Bash", "Read"]
---

# /status - Check Execution Progress

Shows current status of autonomous execution.

```
/status
```

## Output

```
═══════════════════════════════════════════════════════════════════
 Execution Status
═══════════════════════════════════════════════════════════════════

 Task: "Implement dark mode with system preference detection"
 Intent: FEATURE | Complexity: 3/5 | Strategy: ORCHESTRATED

 Status: in_progress

 Progress: ━━━━━━━━━━░░░░░░░░░░ 50%
           Phase 2 of 4

 Completed Phases:
 ✓ 1. ThemeProvider setup [verified: 3/3 tests passed]
 ✓ 2. useTheme hook [verified: 5/5 tests passed]

 Current Phase:
 → 3. Toggle component [in progress]

 Remaining:
 ○ 4. Integration

 Time: Started 15 min ago
 Tokens: ~45,000 used

 Orchestrator: Running (PID: 12345)

═══════════════════════════════════════════════════════════════════
```

## Status Values

| Status | Meaning |
|--------|---------|
| `pending` | Not started yet |
| `in_progress` | Currently executing |
| `handoff_pending` | Waiting for new session |
| `completed` | Successfully finished |
| `stuck` | Failed, needs help |
| `cancelled` | User cancelled |

## No Active Execution

```
═══════════════════════════════════════════════════════════════════
 Execution Status
═══════════════════════════════════════════════════════════════════

 Status: No active execution

 To start: /do <your task>
 To resume: /do --continue

═══════════════════════════════════════════════════════════════════
```

## Stuck Status

```
═══════════════════════════════════════════════════════════════════
 Execution Status
═══════════════════════════════════════════════════════════════════

 Task: "Add payment integration"
 Status: stuck

 Problem:
   Phase 3 failed after 3 attempts
   Error: Stripe API key not configured

 Checkpoint: chk-20250126-143000

 Options:
 • Fix the issue and run: /do --continue
 • See details: cat .claude/auto-execution/stuck-report-phase-3.md
 • Cancel: /cancel

═══════════════════════════════════════════════════════════════════
```

## Implementation

Reads from:
- `.claude/state.json` - Unified state
- `.claude/auto-execution/state.yaml` - Legacy state (if exists)
- `.claude/auto-execution/tasks.json` - Task details

Uses:
- `scripts/state-manager.sh status` - For state display
- `bin/claude-agi --status` - For orchestrator status
