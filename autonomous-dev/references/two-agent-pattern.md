# Two-Agent Pattern for Long-Running Tasks

**Source:** Anthropic Engineering Blog - "Effective Harnesses for Long-Running Agents"

## Overview

The Two-Agent Pattern separates initialization from execution, providing cleaner session
boundaries and better context management for long-running autonomous development tasks.

## Agent Roles

### Initializer Agent (Runs Once)

The Initializer Agent runs at the start of a new task. It:

1. **Analyzes the codebase** - Understands project structure
2. **Detects project profile** - Identifies framework, test runner, etc.
3. **Classifies work type** - FRONTEND, BACKEND, FULLSTACK, etc.
4. **Creates execution plan** - Decomposes into atomic tasks
5. **Sets up state machine** - Initializes auto-state-machine.yaml
6. **Writes checkpoints** - Creates initial memory files

**Output:**
- `.claude/project-profile.yaml`
- `.claude/auto-context.yaml`
- `.claude/plans/auto-{timestamp}.md`
- `.claude/auto-state-machine.yaml`

**The Initializer Agent then exits**, handing off to Coding Agents.

### Coding Agent (Runs Each Session)

Coding Agents execute individual tasks. Each Coding Agent:

1. **Reads checkpoint** - Understands current state
2. **Executes ONE task** - In isolated worktree
3. **Follows TDD** - Red-Green-Refactor-Mutate
4. **Signals completion** - READY_FOR_QA
5. **Writes checkpoint** - For next session/agent

**Output:**
- Task implementation in worktree branch
- Updated progress file
- Checkpoint for continuation

## Session Boundaries

```
┌─────────────────────────────────────────────────────────────┐
│ Session 1: Initialization                                   │
│                                                             │
│   Initializer Agent                                         │
│     ├── Detect project                                      │
│     ├── Classify work                                       │
│     ├── Create plan                                         │
│     ├── Write initial checkpoint                            │
│     └── EXIT                                                │
│                                                             │
│   Output: Plan + State Machine ready                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Session 2-N: Execution                                      │
│                                                             │
│   Coding Agent (per task group)                             │
│     ├── Read checkpoint                                     │
│     ├── Execute parallel group                              │
│     ├── Signal READY_FOR_QA                                 │
│     ├── Write checkpoint                                    │
│     └── EXIT (or continue to next group)                    │
│                                                             │
│   Output: Implemented tasks + Checkpoints                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Session N+1: Integration                                    │
│                                                             │
│   Integration Agent                                         │
│     ├── Read checkpoint                                     │
│     ├── Merge all branches                                  │
│     ├── Run final verification                              │
│     ├── Generate report                                     │
│     └── Signal AUTO_COMPLETE                                │
│                                                             │
│   Output: Merged code + Verification report                 │
└─────────────────────────────────────────────────────────────┘
```

## Integration with autonomous-dev

### Enabling Two-Agent Mode

In `.claude/auto-context.yaml`:

```yaml
execution_mode: two_agent  # or: single_agent (default)
agents:
  initializer:
    max_iterations: 10      # Limit for init phase
    skills: [project-detector, work-type-classifier, task-decomposer]
  coding:
    max_iterations: 50      # Per task group
    skills: [verification-runner, mutation-tester]
```

### /auto Command with Two-Agent Mode

When two-agent mode is enabled:

```bash
# First invocation runs Initializer Agent
/auto "Build user authentication system"

# Output:
# Initializer Agent complete.
# Plan created: .claude/plans/auto-20250118-100000.md
# Run /auto-continue to start execution.

# Subsequent invocations run Coding Agents
/auto-continue

# Output:
# Coding Agent: Executing parallel group 1...
# Checkpoint written. Run /auto-continue for next group.
```

### Auto-Detection

autonomous-dev can auto-detect when to use two-agent mode:

```yaml
# Auto-enable if:
auto_two_agent:
  enabled: true
  conditions:
    - task_count >= 5        # Many tasks benefit from separation
    - estimated_time >= 30m  # Long tasks need session boundaries
    - parallelization: true  # Parallel execution implies multi-session
```

## Benefits

| Aspect | Single Agent | Two-Agent |
|--------|--------------|-----------|
| Context usage | ~47K initial | ~7K per session |
| Session boundaries | None | Clear handoffs |
| Resume capability | Difficult | Easy via checkpoints |
| Parallelization | In-session | Cross-session |
| Token efficiency | Lower | Higher |

## Memory Files

The Two-Agent Pattern uses these memory files for handoff:

```
.claude/
├── auto-state-machine.yaml    # Current state
├── auto-progress.yaml         # Task status
├── auto-context.yaml          # Work type + config
├── auto-memory/
│   ├── context-summary.md     # Full context for resume
│   ├── phase-*-summary.md     # Phase summaries
│   └── next-actions.md        # What to do next
└── plans/
    └── auto-*.md              # Execution plan
```

## When to Use Two-Agent Mode

**Use Two-Agent Pattern when:**
- Task has 5+ subtasks
- Parallelization is enabled
- Estimated execution > 30 minutes
- Multiple session boundaries expected

**Use Single Agent when:**
- Simple, quick tasks
- < 5 subtasks
- No parallelization needed
- Can complete in one session

## Implementation Checklist

To fully implement Two-Agent Pattern:

- [x] Initializer agent responsibilities defined
- [x] Coding agent responsibilities defined
- [x] Checkpoint handoff protocol
- [x] Session boundary management
- [x] Progress tracking across sessions
- [ ] Auto-detection of mode
- [ ] /auto command flag for explicit mode
