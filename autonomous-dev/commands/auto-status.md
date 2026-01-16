---
description: Check progress of autonomous execution
allowed-tools: ["Read", "Bash"]
---

# Check Autonomous Execution Status

1. Read `.claude/auto-progress.yaml`
2. Display:
   - Overall status
   - Tasks completed / in progress / pending
   - Current iteration count
   - Any errors or blockers
3. Show active worktrees:
   ```bash
   git worktree list
   ```
