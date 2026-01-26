# Migration Guide: v3.x → v4.0

This guide helps you transition from the v3.x multi-command system to the v4.0 AGI-like interface.

## Quick Migration

| Old Command | New Command | Notes |
|-------------|-------------|-------|
| `/auto <task>` | `/do <task>` | Same functionality, smarter execution |
| `/auto-smart <task>` | `/do <task>` | `/do` automatically adapts |
| `/auto-lite <task>` | `/do <task>` | `/do` detects simple tasks |
| `/auto-plan <task>` | `/do <task>` | Or use old command (still works) |
| `/auto-execute` | `/do --continue` | Or use old command |
| `/auto-status` | `/status` | Simpler command |
| `/auto-cancel` | `/cancel` | Simpler command |

## What Changed

### Before (v3.x): Choose Your Command

```
/auto           - Full autonomous with approval gates
/auto-smart     - Fire-and-forget, no approval
/auto-lite      - Quick mode for simple tasks
/auto-plan      - Planning only
/auto-execute   - Execute existing plan
/auto-overnight - Unattended overnight mode
```

**Problem:** You had to guess which command was right for your task.

### After (v4.0): One Smart Command

```
/do <task>      - Does the right thing automatically
```

The `/do` command:
1. **Parses** your natural language input
2. **Enriches** with memory context (local + global)
3. **Classifies** complexity (1-5) and work type
4. **Resolves** ambiguity (asks only when critical)
5. **Selects** strategy (DIRECT for simple, ORCHESTRATED for complex)
6. **Executes** with TDD discipline and checkpoints

## New Features in v4.0

### 1. Intent Engine

Natural language understanding with reference resolution:

```bash
# References to previous work
/do Fix that auth bug from yesterday

# Composite requests
/do Add login and signup pages with validation

# Implicit context
/do Make it mobile responsive
```

### 2. Hybrid Memory System

**Local Memory** (per-project, 90-day retention):
- Recent sessions and decisions
- Project-specific patterns
- What worked in this codebase

**Global Memory** (cross-project, forever):
- Universal patterns by domain
- Technology gotchas
- Shared learnings

### 3. Adaptive Execution

| Complexity | Mode | Checkpoints | TDD |
|------------|------|-------------|-----|
| 1-2 | DIRECT | No | Optional |
| 3-5 | ORCHESTRATED | Per phase | Required |

### 4. Multi-Session Orchestration

Install the external orchestrator for long tasks:

```bash
./autonomous-dev/bin/install-claude-agi.sh
```

Then use:

```bash
# Interactive (prompts between sessions)
claude-agi "Implement feature X"

# Overnight (fully autonomous)
claude-agi --overnight "Major refactoring"

# Continue interrupted work
claude-agi --continue
```

### 5. ML-Based Complexity Scoring

The system learns from your coding patterns:

| Phase | Tasks Completed | Method |
|-------|-----------------|--------|
| Cold Start | 0-20 | Heuristics only |
| Hybrid | 20-50 | Heuristics + embeddings |
| Full ML | 50+ | Trained model |

## Breaking Changes

### 1. State Files Location

**v3.x:**
```
.claude/auto-context.yaml
.claude/auto-state.yaml
.claude/auto-*.yaml
```

**v4.0:**
```
.claude/auto-execution/
├── state.yaml        # Unified state
├── tasks.json        # Task list
└── next-session.md   # Context for resume
```

### 2. Checkpoint Format

Checkpoints are now more comprehensive:
- Full git diff
- Compressed context summary
- Resume instructions

### 3. Memory Locations

```
# Local memory (project-specific)
.claude/memory/local/
├── sessions.yaml
├── patterns.yaml
├── learnings/
└── quirks.yaml

# Global memory (cross-project)
~/.claude/global-memory/
├── patterns/
├── gotchas/
└── feedback/
```

## Compatibility

### Deprecated Commands Still Work

All `/auto-*` commands still work but show deprecation warnings:

```
> /auto Add feature X

WARNING: /auto is deprecated. Use /do instead.
Continuing with legacy mode...
```

### Clean Migration

To fully migrate:

1. **Update your muscle memory:** `/do` instead of `/auto`

2. **Check for old state files:**
   ```bash
   ls .claude/auto-*.yaml
   ```
   These can be deleted if no active execution.

3. **Install claude-agi (optional):**
   ```bash
   ./autonomous-dev/bin/install-claude-agi.sh
   ```

## Troubleshooting

### "Command /do not found"

Ensure plugin is installed and Claude Code restarted:
```bash
claude plugin list | grep autonomous-dev
```

### "Memory not loading"

Check permissions:
```bash
ls -la .claude/memory/
ls -la ~/.claude/global-memory/
```

### "Complexity scoring seems off"

The ML model needs data to learn. After ~20 tasks, hybrid scoring kicks in.

To provide feedback:
```bash
# After task completion
./autonomous-dev/scripts/memory-cleanup.sh feedback <task-id> <correct|incorrect>
```

## Getting Help

- **Plugin issues:** https://github.com/adiomas/autonomous-dev/issues
- **Check version:** Look at `.claude-plugin/plugin.json` - should be `4.0.0`
- **Reset memory:** Delete `.claude/memory/` to start fresh
