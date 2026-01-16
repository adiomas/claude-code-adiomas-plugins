---
description: Execute an existing plan
argument-hint: "[plan-file-path]"
allowed-tools: ["Task", "Bash", "Read", "Write", "Edit", "Glob", "Grep", "TodoWrite"]
---

# Execute Existing Plan

1. Load plan from argument or most recent `.claude/plans/auto-*.md`
2. Verify plan is approved (check for user approval marker)
3. Execute PHASE 4-6 from main /auto command
4. Do NOT re-ask requirement questions - plan has all info

If plan is missing or invalid, error out with instructions to run /auto-plan first.
