---
name: execution-bootstrap
description: >
  This skill should be invoked at the START of any /auto-execute session.
  It reads state files from .claude/auto-execution/ and establishes context
  for continuing autonomous execution. Provides fast context bootstrap
  with minimal token usage (~1KB vs ~50KB of full context).
---

# Execution Bootstrap Skill

Bootstrap a coding session from prepared state files. This skill implements
the "Coding Agent" half of Anthropic's Two-Agent Pattern.

## When This Skill Activates

- `/auto-execute` command is invoked
- `/auto-execute --overnight` is invoked
- `/auto-execute --continue` is invoked
- Any session continuing autonomous execution

## Core Principle

**Minimal context, maximum efficiency.**

From Anthropic's research:
> "The key insight was finding a way for agents to quickly understand
> the state of work when starting with a fresh context window."

This skill reads ~1KB of context instead of ~50KB, leaving more room for coding.

## Bootstrap Protocol

### Step 1: Verify Preparation Exists

```bash
# Check for required state files
if [[ ! -f .claude/auto-execution/state.yaml ]]; then
  echo "ERROR: No prepared execution found."
  echo "Run /auto-prepare first to create execution state."
  exit 1
fi
```

**If files missing:** Stop and instruct user to run `/auto-prepare`.

### Step 2: Read State Files (In Order)

Read files in this specific order for optimal context:

1. **`next-session.md`** (FIRST - most important)
   - Contains human-readable context summary
   - Key decisions made during planning
   - Gotchas and learnings
   - Files to focus on

2. **`state.yaml`** (machine state)
   - Current status
   - Current task/group
   - Verification commands

3. **`tasks.json`** (task details)
   - Find first task with `status: "pending"`
   - Get task description, files, verification

### Step 3: Validate Current State

Check state.yaml for status:

```yaml
status: ready_for_execution  # Can proceed
status: in_progress          # Resume from current_task
status: completed            # Nothing to do
status: stuck                # Review stuck-report.md
```

**Status Actions:**

| Status | Action |
|--------|--------|
| `ready_for_execution` | Start from task-1 |
| `in_progress` | Resume from `current_task` |
| `completed` | Inform user all done |
| `stuck` | Read stuck-report.md, ask user |

### Step 4: Load Current Task

From tasks.json, find the current task:

```javascript
// Pseudo-code
const currentTask = tasks.find(t =>
  t.status === "pending" || t.status === "in_progress"
);

if (!currentTask) {
  // All tasks done, proceed to verification
  status = "verification";
}
```

### Step 5: Verify Prerequisites

Before starting the task:

1. **Check dependencies are complete:**
   ```javascript
   for (const depId of currentTask.dependencies) {
     const dep = tasks.find(t => t.id === depId);
     if (dep.status !== "done") {
       throw new Error(`Dependency ${depId} not complete`);
     }
   }
   ```

2. **Run initial verification:**
   ```bash
   # Ensure current state is clean
   npm test  # or project-specific command
   npm run lint
   ```

   If verification fails before we even start:
   - Something is broken from previous session
   - Invoke systematic-debugging skill
   - Fix before proceeding

### Step 6: Output Bootstrap Summary

After reading state, output a summary:

```
═══════════════════════════════════════════════════════════════════
 EXECUTION BOOTSTRAP COMPLETE
═══════════════════════════════════════════════════════════════════

 Feature: {feature name}
 Status:  {in_progress}

 Progress: {completed}/{total} tasks ({percentage}%)

 Current Task: {task-id}
 └── {task name}
 └── Files: {file list}
 └── Verification: {command}

 Key Context:
 • {decision 1 from next-session.md}
 • {decision 2 from next-session.md}

 Ready to execute. Following TDD discipline.
═══════════════════════════════════════════════════════════════════
```

## Context Efficiency

### What We Load (~1KB)

```
next-session.md:
  - Current state summary (2-3 lines)
  - Key decisions (3-5 bullet points)
  - Gotchas (2-3 items)
  - Next steps (numbered list)

state.yaml:
  - Status, current_task, verification commands

tasks.json:
  - Only current task details
  - NOT the full task list
```

### What We DON'T Load

- Full conversation history from planning
- Design documents
- All task descriptions
- Previous session transcripts

### Why This Works

From Cursor's research:
> "Workers pick up tasks and focus entirely on completing them.
> They don't coordinate with other workers or worry about the big picture."

The coding agent doesn't need to understand WHY we're building something.
It just needs to know WHAT to build next and HOW to verify it works.

## Resume Protocol

When `--continue` flag is used:

### Step 1: Check for Interrupted Work

```yaml
# In state.yaml
current_task: task-3
session_history:
  - session_id: "abc123"
    started_at: "2024-01-15T10:00:00Z"
    ended_at: "2024-01-15T10:45:00Z"
    reason: "context_limit"
    last_task_completed: "task-2"
```

### Step 2: Recover Context

Read the last entry in session_history to understand:
- Why previous session ended
- What was the last completed task
- Any issues encountered

### Step 3: Continue from Checkpoint

If task was in_progress but not completed:
1. Check if any files were partially modified
2. Run git status to see uncommitted changes
3. Decide: continue task or rollback and restart

**Safe default:** If unclear, rollback uncommitted changes and restart task.

```bash
# Rollback uncommitted changes
git checkout -- .
# Restart task from clean state
```

## Integration with /auto-execute

This skill is automatically invoked by `/auto-execute`:

```markdown
# In auto-execute.md

## BOOTSTRAP (Always First)

Invoke execution-bootstrap skill:
1. Read state files
2. Validate preparation exists
3. Load current task
4. Output bootstrap summary

Then proceed with execution loop.
```

## Error Handling

### Missing State Files

```
ERROR: Execution state not found

Expected files at .claude/auto-execution/:
  • state.yaml (missing)
  • tasks.json (missing)
  • next-session.md (missing)

Resolution: Run /auto-prepare first to create execution state.
```

### Corrupted State

If JSON parsing fails or state is invalid:

```
ERROR: Corrupted execution state

File: .claude/auto-execution/tasks.json
Error: Unexpected token at line 15

Resolution options:
1. Fix the JSON manually
2. Re-run /auto-prepare to regenerate
3. Check git history for previous version
```

### All Tasks Already Complete

```
INFO: All tasks already complete!

Progress: 5/5 tasks (100%)

Remaining steps:
1. Run final verification
2. Review changes
3. Merge branch if satisfied

Run verification? [Y/n]
```

## State File Schemas

### state.yaml Schema

```yaml
version: "1.0"
status: ready_for_execution | in_progress | completed | stuck
mode: interactive | overnight
feature: "feature-name"
plan_file: ".claude/plans/auto-*.md"
tasks_file: ".claude/auto-execution/tasks.json"
created_at: "ISO timestamp"
current_task: "task-id" | null
current_group: 1
total_groups: N
verification:
  test_command: "npm test"
  lint_command: "npm run lint"
  build_command: "npm run build"
session_history:
  - session_id: "unique-id"
    started_at: "ISO timestamp"
    ended_at: "ISO timestamp"
    reason: "completed | context_limit | error | user_interrupt"
    tasks_completed: ["task-1", "task-2"]
    last_task_completed: "task-2"
```

### tasks.json Schema

```json
{
  "version": "1.0",
  "feature": "feature-slug",
  "tasks": [
    {
      "id": "task-1",
      "name": "Short name",
      "description": "Full description",
      "files": ["path/to/file.ts"],
      "dependencies": [],
      "verification_command": "npm test -- file.test.ts",
      "expected_output": "pattern to match",
      "complexity": "S|M|L",
      "status": "pending|in_progress|done|skipped",
      "started_at": "ISO timestamp | null",
      "completed_at": "ISO timestamp | null",
      "evidence": "verification output | null"
    }
  ],
  "execution_strategy": {
    "mode": "parallel|sequential",
    "groups": []
  }
}
```

## Best Practices

1. **Read next-session.md first** - Most condensed, human-friendly context
2. **Trust the state files** - They were created with full context
3. **Don't re-analyze the codebase** - Focus on current task only
4. **Update state after each task** - Enable clean resume
5. **Keep next-session.md updated** - Add learnings as you go
