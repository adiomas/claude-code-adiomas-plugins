---
name: parallel-orchestrator
description: >
  This skill should be used when the user asks to "run tasks in parallel",
  "create worktrees", "dispatch parallel agents", "orchestrate execution",
  or when autonomous-dev needs to execute independent tasks simultaneously.
  Manages git worktrees for isolated parallel development.
---

# Parallel Orchestration Skill

Coordinate multiple parallel agents working on independent tasks using git worktrees for isolation.

## Worktree Strategy

Each independent task receives its own git worktree:
- **Isolated filesystem** - No interference between tasks
- **Own branch** - Clean git history per task
- **Independent testing** - Run verification without conflicts
- **Easy merging** - Standard git merge workflow

## Dispatch Protocol

### Step 1: Create Worktrees

For each task in a parallel group:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/setup-worktree.sh task-{id}
```

This creates:
- Worktree at `/tmp/auto-worktrees/task-{id}/`
- Branch at `auto/task-{id}`
- Copied project profile for context

### Step 2: Dispatch Agents

Use the Task tool for each parallel task:
```
Task(
  subagent_type: "general-purpose",
  prompt: "Work in worktree at {path}. Task: {description}.
           Verification: {commands}.
           When done, commit and output: <promise>TASK_DONE: {id}</promise>",
  run_in_background: true
)
```

### Step 3: Track Progress

Update `.claude/auto-progress.yaml` with task status:
```yaml
tasks:
  task-1:
    status: in_progress
    branch: auto/task-1
    iterations: 1
```

### Step 4: Wait for Completion

Monitor agent output files for completion signals.

### Step 5: Handle Failures

Failure handling protocol:
- If agent fails → retry up to 3 times
- If still fails → mark task as failed
- Report all failures to user at end

## Merge Protocol

After all parallel tasks complete:

### Step 1: Return to Main Worktree

Switch back to the primary working directory.

### Step 2: Merge Branches

Execute merges in dependency order:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/merge-branches.sh
```

### Step 3: Handle Conflicts

For merge conflicts:
- Attempt automatic resolution for simple cases
- Escalate complex conflicts to user
- Use conflict-resolver skill when needed

### Step 4: Clean Up

Remove completed worktrees:
```bash
git worktree remove /tmp/auto-worktrees/task-{id}
git branch -d auto/task-{id}
```

## Additional Resources

### Reference Files

For detailed worktree management:
- **`references/worktree-management.md`** - Complete git worktree guide, common issues, best practices

## Script Reference

| Script | Purpose |
|--------|---------|
| `scripts/setup-worktree.sh` | Create isolated worktree |
| `scripts/merge-branches.sh` | Merge all auto/* branches |
