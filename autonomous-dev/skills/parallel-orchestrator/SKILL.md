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

## Auto-Invoke Trigger (NEW)

This skill is automatically invoked when:
1. `task-decomposer` found >= 3 independent tasks
2. State machine transitioned to `PARALLELIZE`
3. `parallelization.enabled == true` in config (default)

**Skip conditions:**
- All tasks have linear dependencies
- `independent_tasks < 3`
- `parallelization.enabled == false` in `.claude/auto-context.yaml`

## Pre-Flight Check

Before creating worktrees, verify:

```bash
# Check parallelization config
if [[ -f ".claude/auto-context.yaml" ]]; then
  enabled=$(yq -r '.parallelization.enabled // true' .claude/auto-context.yaml)
  min_tasks=$(yq -r '.parallelization.min_tasks // 3' .claude/auto-context.yaml)
  max_agents=$(yq -r '.parallelization.max_agents // 5' .claude/auto-context.yaml)
fi
```

## Execution Mode Output (REQUIRED)

Always output the execution decision:

**For PARALLEL execution:**
```
┌─────────────────────────────────────────────────────────────┐
│ ⚡ Execution Mode: PARALLEL                                 │
│    Tasks: 5 independent files detected                      │
│    Agents: 3 (limited by max_agents config)                 │
│                                                             │
│    Parallel Group 1:                                        │
│      ├── Agent 1: [worktree-1] globals.css, tailwind.config │
│      ├── Agent 2: [worktree-2] sidebar.tsx                  │
│      └── Agent 3: [worktree-3] header.tsx                   │
│                                                             │
│    Parallel Group 2 (after Group 1):                        │
│      ├── Agent 4: [worktree-4] stat-bar.tsx                 │
│      └── Agent 5: [worktree-5] onboarding.tsx               │
│                                                             │
│    Progress: [░░░░░░░░░░░░░░░░] 0/5 agents complete         │
└─────────────────────────────────────────────────────────────┘
```

**For SEQUENTIAL execution:**
```
┌─────────────────────────────────────────────────────────────┐
│ ⏸️ Execution Mode: SEQUENTIAL                               │
│    Reason: Only 2 files with dependencies                   │
│    Order: types.ts → component.tsx                          │
│                                                             │
│    Skipping parallel orchestration (threshold not met)      │
└─────────────────────────────────────────────────────────────┘
```

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
| `scripts/state-transition.sh` | Manage state machine |

## Progress Tracking (REQUIRED)

Update progress display after each agent completion:

```
┌─────────────────────────────────────────────────────────────┐
│ ⚡ Execution Mode: PARALLEL                                 │
│    Progress: [████████░░░░░░░░] 3/5 agents complete         │
│                                                             │
│    ✅ Agent 1: globals.css, tailwind.config (done)          │
│    ✅ Agent 2: sidebar.tsx (done)                           │
│    ✅ Agent 3: header.tsx (done)                            │
│    ⏳ Agent 4: stat-bar.tsx (in progress)                   │
│    ⏳ Agent 5: onboarding.tsx (in progress)                 │
└─────────────────────────────────────────────────────────────┘
```

## Integration with State Machine

After parallel execution completes:

```bash
# Transition to INTEGRATE state for merging
${CLAUDE_PLUGIN_ROOT}/scripts/state-transition.sh transition INTEGRATE
```

## Configuration Reference

In `.claude/auto-context.yaml`:

```yaml
parallelization:
  enabled: true           # Master switch
  min_tasks: 3            # Minimum independent tasks to trigger
  max_agents: 5           # Maximum concurrent agents
  auto_cleanup: true      # Remove worktrees after merge
  retry_on_failure: 3     # Retry failed agents N times
```

## When NOT to Use This Skill

Do NOT use this skill when:

1. **Less than 3 independent tasks** - Overhead outweighs benefits for small task counts
2. **All tasks have linear dependencies** - Sequential execution is required
3. **Single file changes** - Use simple sequential execution
4. **User disabled parallelization** - Check `parallelization.enabled` in config
5. **Limited system resources** - Worktrees consume disk space
6. **Shared mutable state** - Tasks that write to same files cannot parallelize

## Quality Standards

1. **ALWAYS** check pre-flight conditions before creating worktrees
2. **ALWAYS** display execution mode (PARALLEL or SEQUENTIAL) to user
3. **NEVER** exceed `max_agents` configuration setting
4. **ALWAYS** handle failed agents with retry logic
5. **ALWAYS** clean up worktrees after successful merge
6. **PRIORITIZE** running conflict-resolver skill if merge fails
