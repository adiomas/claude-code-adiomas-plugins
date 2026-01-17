# Autonomous-Dev Plugin Architecture

This document explains the architecture of the autonomous-dev plugin, including its state machine, phase workflow, and component interactions.

## Overview

The autonomous-dev plugin is a sophisticated orchestration system that manages the full lifecycle of autonomous development tasks. It uses a state machine to track progress, parallel agents for execution, and graceful degradation when resource limits are approached.

## Core Components

### 1. State Machine

The central coordination mechanism, stored in `.claude/auto-state-machine.yaml`:

```yaml
version: "3.0"
current_state: EXECUTE  # IDLE, DETECT, CLASSIFY, PLAN, EXECUTE, INTEGRATE, REVIEW, COMPLETE
work_type: FRONTEND     # FRONTEND, BACKEND, FULLSTACK, RESEARCH, etc.
session_id: "abc123"
classification_confidence: 0.85
mandatory_skills:
  - frontend-design
  - test-driven-development
completed_phases: [DETECT, CLASSIFY, PLAN]
token_usage:
  budget: 200000
  estimated: 45000
  warning_threshold: 0.80
  checkpoint_threshold: 0.95
```

### 2. Phase Flow

```
IDLE → DETECT → CLASSIFY → PLAN → EXECUTE → INTEGRATE → REVIEW → COMPLETE
          ↑                                                         │
          └─────────────────── /auto-continue ──────────────────────┘
```

#### Phase Responsibilities

| Phase | Purpose | Key Script/Skill |
|-------|---------|------------------|
| DETECT | Detect project type | `detect-project.sh` |
| CLASSIFY | Determine work type | `work-type-classifier` |
| PLAN | Decompose into tasks | `task-decomposer` |
| EXECUTE | Run parallel agents | `parallel-orchestrator` |
| INTEGRATE | Merge branches | `conflict-resolver` |
| REVIEW | Final verification | `verification-runner` |

### 3. Token Budget System

Manages context window usage to prevent degradation:

```
┌─────────────────────────────────────────┐
│ Token Budget Controller                 │
├─────────────────────────────────────────┤
│ Budget: 200,000 tokens                  │
│ Used: 45,000 (22.5%)                    │
│ Warning: 160,000 (80%)                  │
│ Checkpoint: 190,000 (95%)               │
└─────────────────────────────────────────┘
```

When thresholds are reached:
- **80% (Warning)**: Start context summarization
- **95% (Checkpoint)**: Save state, initiate handoff

### 4. Parallel Execution Architecture

```
Main Worktree (./)
    │
    ├── /tmp/auto-worktrees/task-1/ → Agent 1
    │       └── Branch: auto/task-1
    │
    ├── /tmp/auto-worktrees/task-2/ → Agent 2
    │       └── Branch: auto/task-2
    │
    └── /tmp/auto-worktrees/task-3/ → Agent 3
            └── Branch: auto/task-3
```

Each agent:
1. Works in isolated worktree
2. Follows TDD discipline
3. Runs verification
4. Signals completion with `<promise>TASK_DONE: task-id</promise>`

### 5. Memory System

Persistent memory for session resume:

```
.claude/auto-memory/
├── context-summary.md      # Compressed session context
├── phase-plan-summary.md   # Planning phase summary
├── phase-execute-summary.md # Execution phase summary
├── task-1-learnings.md     # Per-task learnings
├── task-2-learnings.md
└── next-actions.md         # Resume instructions
```

## Component Interaction

### Hook System

```
SessionStart
    │
    └── detect-project.sh → Create project-profile.yaml

Stop
    │
    └── stop-hook.sh → Check completion promises
                     → Increment iteration
                     → Check token budget
                     → Save checkpoint if needed

PostToolUse (Edit/Write)
    │
    └── post-tool.sh → Optional auto-verification
```

### Skill Invocation Flow

```
User Request
    │
    ▼
work-type-classifier → Detect FRONTEND/BACKEND/etc.
    │
    ▼
State Machine → Set mandatory_skills based on work_type
    │
    ▼
pre-phase-hook → Enforce skill invocation
    │
    ▼
Phase Execution → Skills loaded automatically
```

## Directory Structure

```
autonomous-dev/
├── .claude-plugin/plugin.json   # Plugin manifest
├── commands/                    # Slash commands
├── skills/                      # Auto-loading skills
│   └── {skill}/
│       ├── SKILL.md            # Skill definition
│       └── references/          # Supporting docs
├── agents/                      # Specialized agents
├── hooks/                       # Lifecycle hooks
│   ├── hooks.json              # Hook configuration
│   └── *.sh                    # Hook scripts
├── scripts/                     # Utility scripts
├── references/                  # Plugin-level docs
└── README.md
```

## State Transitions

### Valid Transitions

```
IDLE → DETECT (on /auto start)
DETECT → CLASSIFY (after project profile created)
CLASSIFY → PLAN (after work type determined)
PLAN → EXECUTE (after user approves plan)
EXECUTE → INTEGRATE (after all tasks complete)
INTEGRATE → REVIEW (after branches merged)
REVIEW → COMPLETE (after verification passes)
```

### Error Transitions

```
Any State → IDLE (on /auto-cancel)
Any State → CHECKPOINT (on token budget exceeded)
CHECKPOINT → IDLE (session ends, resume with /auto-continue)
```

## Error Handling

### Graceful Degradation Hierarchy

1. **Task failure**: Retry up to 3 times
2. **Agent failure**: Escalate to user
3. **Token budget warning**: Summarize context
4. **Token budget critical**: Save checkpoint, handoff
5. **Max iterations**: Force checkpoint

### Recovery Procedures

```bash
# Recover from corrupted state
scripts/checkpoint-manager.sh restore

# Clean up failed execution
/auto-cancel

# Resume from checkpoint
/auto-continue
```

## Performance Considerations

### Parallel Execution Limits

- Default: max 5 concurrent agents
- Configurable in `.claude/auto-context.yaml`
- Worktrees consume disk space

### Token Budget Optimization

- Phase-specific budgets prevent runaway consumption
- Incremental mutation testing (changed files only)
- Lazy skill loading

## Extension Points

### Adding New Frameworks

1. Edit `scripts/detect-project.sh`
2. Add detection patterns
3. Update `skills/project-detector/references/supported-frameworks.md`

### Adding New Skills

1. Create `skills/{skill-name}/SKILL.md`
2. Add trigger phrases in description
3. Create `references/` directory
4. Update `skills/work-type-classifier/references/skill-catalog.md`

### Adding New Agents

1. Create `agents/{agent-name}.md`
2. Include `model:`, `color:`, `tools:` in frontmatter
3. Add `<example>` blocks for triggering
