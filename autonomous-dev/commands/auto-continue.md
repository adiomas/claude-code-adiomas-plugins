---
name: auto-continue
description: Resume autonomous execution from checkpoint after session interrupt or token limit
argument-hint: ""
allowed-tools: ["Task", "Bash", "Read", "Write", "Edit", "Glob", "Grep", "TodoWrite"]
---

# /auto-continue - Resume Autonomous Session

Resume an interrupted autonomous development session from the last checkpoint.

## When to Use

- After session was interrupted (network, timeout, manual stop)
- After token limit triggered graceful handoff
- When continuing work in a new session
- After `/auto-status` shows incomplete session

## Resume Process

### Step 1: Detect Previous Session

```bash
# Check for existing state machine
if [[ -f ".claude/auto-state-machine.yaml" ]]; then
    echo "Previous session found"
    RESUME_MODE=true
else
    echo "No previous session to resume"
    exit 0
fi
```

Read the state machine to understand where we left off:
- Current state (DETECT, CLASSIFY, PLAN, EXECUTE, INTEGRATE, REVIEW)
- Work type (FRONTEND, BACKEND, etc.)
- Completed phases
- Checkpoint files

### Step 2: Load Context from Memory Files

Read `.claude/auto-memory/` files to reconstruct context:

1. **context-summary.md** - Full context overview (READ THIS FIRST)
2. **phase-*-summary.md** - What was decided in each completed phase
3. **task-*-learnings.md** - Learnings from executed tasks
4. **next-actions.md** - Specific instructions for resume

**CRITICAL:** Do NOT re-run completed phases. Trust the checkpoints.

### Step 3: Identify Resume Point

Based on `current_state` in state machine:

| Current State | Resume Action |
|---------------|---------------|
| DETECT | Re-run detection (rare - usually complete) |
| CLASSIFY | Read auto-context.yaml, continue to PLAN |
| PLAN | Read existing plan, get user approval, continue to EXECUTE |
| EXECUTE | Check auto-progress.yaml for pending tasks, continue execution |
| INTEGRATE | Continue merging branches |
| REVIEW | Run fresh verification |
| RESEARCH | Continue from current research phase |

### Step 4: Resume Execution

For EXECUTE phase resume:

```yaml
# Read .claude/auto-progress.yaml to find:
tasks:
  task-1:
    status: done       # ← Skip
  task-2:
    status: done       # ← Skip
  task-3:
    status: in_progress  # ← RESUME HERE
    branch: auto/task-3
    iterations: 2
  task-4:
    status: pending    # ← Do after task-3
```

1. Find first non-done task
2. Check if worktree exists at `/tmp/auto-worktrees/task-{id}/`
3. If exists, switch to it and continue
4. If not, create new worktree and restart task

### Step 5: Validate State

Before continuing, validate:

```bash
# Verify plan file exists
ls .claude/plans/auto-*.md

# Verify project profile exists
ls .claude/project-profile.yaml

# Verify auto-context exists
ls .claude/auto-context.yaml
```

If any are missing, notify user and ask how to proceed.

## Output Format

On successful resume:

```
=== RESUME SESSION ===
Session ID: auto-20240115-103000
Resuming from: EXECUTE phase
Work Type: FRONTEND
Completed: DETECT, CLASSIFY, PLAN

Pending Tasks:
- task-3: Create Auth API (in_progress, iteration 2)
- task-4: Add Tests (pending)

Mandatory Skills for EXECUTE:
- superpowers:test-driven-development
- frontend-design

Continuing execution...
=== END RESUME ===
```

## Error Handling

### No Session Found
```
No previous autonomous session found.
Use /auto to start a new session.
```

### Corrupted State
```
State machine file is corrupted or incomplete.
Options:
1. Delete .claude/auto-state-machine.yaml and start fresh with /auto
2. Manually fix the state file
3. Check .claude/auto-memory/ for recoverable context
```

### Missing Plan
```
Plan file not found at .claude/plans/auto-*.md
Cannot resume EXECUTE phase without plan.
Options:
1. Re-run /auto-plan to create new plan
2. Check if plan was moved to docs/plans/
```

## Integration with State Machine

This command:
1. Reads `.claude/auto-state-machine.yaml` for current state
2. Reads `.claude/auto-memory/*.md` for context
3. Does NOT transition state (continues from current)
4. Invokes mandatory skills for current phase
5. Continues the autonomous workflow

## Example Usage

```
User: The session was interrupted. Let me continue.

> /auto-continue

Claude: Resuming autonomous session...

Session ID: auto-20240115-103000
Current State: EXECUTE
Work Type: FRONTEND

Reading context from checkpoints...
- Phase 1 (DETECT): Complete - Next.js project detected
- Phase 2 (CLASSIFY): Complete - FRONTEND with DESIGN_QUALITY focus
- Phase 3 (PLAN): Complete - 5 tasks planned

Pending tasks:
- task-3: Create UserProfile component (in_progress)
- task-4: Add unit tests (pending)
- task-5: Integration tests (pending)

Invoking mandatory skills for EXECUTE phase:
- superpowers:test-driven-development
- frontend-design

Continuing with task-3...
```
