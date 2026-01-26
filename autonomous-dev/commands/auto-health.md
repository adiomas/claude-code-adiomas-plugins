---
name: auto-health
description: Check autonomous-dev system health and diagnose issues
---

# Health Check

Run diagnostics on the autonomous-dev system.

## Usage

Just run `/auto-health` to check system status.

## What It Checks

1. **Dependencies** - yq, jq, flock, git, etc.
2. **State Files** - YAML validity, stale locks
3. **Git Status** - Repository state, current branch
4. **Worktrees** - Active and orphaned worktrees
5. **Memory** - Size and file count
6. **Execution** - Current phase and iteration
7. **Logs** - Size and recent errors

## Instructions

Run the health check script and report results:

```bash
bash "$(dirname "$0")/../scripts/health-check.sh"
```

## Interpreting Results

| Status | Meaning |
|--------|---------|
| **HEALTHY** | All systems operational |
| **DEGRADED** | Some warnings, but functional |
| **UNHEALTHY** | Critical issues need attention |

## Common Issues & Fixes

### Stale Lock Files
```bash
find .claude -name "*.lock" -mmin +5 -delete
```

### Orphaned Worktrees
```bash
git worktree prune
rm -rf /tmp/auto-worktrees-$(id -u)/*
```

### Corrupted YAML
```bash
# Check which file is corrupted
yq '.' .claude/auto-state-machine.yaml

# Reset state if needed
rm .claude/auto-state-machine.yaml
```

### Large Memory
```bash
# Clean old memory files
find .claude/memory -mtime +90 -delete
```
