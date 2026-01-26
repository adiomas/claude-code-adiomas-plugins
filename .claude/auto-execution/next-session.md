# Next Session Context

## Quick Start

You are continuing autonomous execution prepared by `/auto-prepare`.

**To execute:**
```bash
# Option 1: Use external orchestrator (recommended for long tasks)
claude-agi --continue

# Option 2: Manual execution
/auto-execute

# Option 3: Overnight mode
claude-agi --overnight
```

## Current State

- **Status:** Ready for execution
- **Feature:** AGI-Like Interface v4.0
- **Next task:** task-0.1 (Create claude-agi orchestrator script)
- **Tasks remaining:** 27
- **Execution groups:** 10

## Project Context

- **Type:** Claude Code Plugin
- **Language:** Markdown skills + Bash scripts
- **No build needed** - plugin system loads markdown directly
- **Test command:** `./autonomous-dev/tests/run-all-tests.sh`

## Key Decisions Made During Planning

1. **Single command `/do`** replaces 10 existing commands
2. **Hibridna memorija** - Local (90 days) + Global (forever with cleanup)
3. **Pametno pogađanje** - Autonomous for most, ask only for critical actions
4. **External orchestrator `claude-agi`** - Enables true multi-session autonomy
5. **Confidence-based** conflict resolution between local/global memory
6. **ML complexity scoring** - Start heuristic, learn from experience
7. **Adaptive TDD** - TDD for complexity 3+, skip for simple
8. **80% token handoff** - Session switch threshold
9. **Escalating failure** - Retry → Pivot → Research → Checkpoint/Ask

## Files to Create (First Group - Parallel)

```
autonomous-dev/bin/claude-agi           # Main orchestrator
autonomous-dev/scripts/request-handoff.sh
autonomous-dev/scripts/state-manager.sh
autonomous-dev/schemas/state.schema.json
autonomous-dev/memory/local-manager.md
autonomous-dev/scripts/local-memory.sh
autonomous-dev/memory/global-manager.md
autonomous-dev/scripts/global-memory.sh
```

## Execution Strategy

**Group 1 (parallel, no deps):**
- task-0.1, task-0.2, task-1.2, task-3.1, task-3.2

**Then sequential groups with dependencies...**

See `tasks.json` for full dependency graph.

## Gotchas / Learnings

- This is a **plugin** - no npm/pnpm, just markdown and bash
- Skills are in `autonomous-dev/skills/` or `autonomous-dev/engine/`
- Commands are in `autonomous-dev/commands/`
- Hooks configuration in `autonomous-dev/hooks/hooks.json`
- Test scripts in `autonomous-dev/tests/`

## Design Documents (Reference)

- `docs/plans/2025-01-26-agi-like-interface-design.md` - Main design
- `docs/plans/2025-01-26-intent-engine-detailed-design.md` - Intent Engine
- `docs/plans/2025-01-26-memory-system-detailed-design.md` - Memory System
- `docs/plans/2025-01-26-execution-engine-detailed-design.md` - Execution Engine
- `docs/plans/2025-01-26-agi-implementation-plan.md` - Implementation Plan

## Execution Instructions

1. Read `state.yaml` for current status
2. Read `tasks.json` for task details and dependencies
3. Start with first pending task in current group
4. For each task:
   - Read task description from tasks.json
   - Create/modify files as specified
   - Run verification command
   - Update tasks.json with evidence
   - Commit changes
5. Update `progress.md` for human readability
6. Update this file with any new learnings
7. If token limit approaching (80%):
   - Create checkpoint
   - Signal handoff
   - Orchestrator will start new session
