---
name: auto-cancel
description: Cancel autonomous execution and clean up
argument-hint: ""
allowed-tools: ["Bash", "Write", "Read"]
---

# Cancel Autonomous Execution

1. Set `.claude/auto-progress.yaml` status to "cancelled"
2. Kill any background agents (if possible)
3. Clean up worktrees:
   ```bash
   git worktree list | grep auto- | awk '{print $1}' | xargs -I {} git worktree remove {}
   ```
4. Delete auto branches:
   ```bash
   git branch | grep auto/ | xargs -I {} git branch -D {}
   ```
5. Confirm cancellation to user
