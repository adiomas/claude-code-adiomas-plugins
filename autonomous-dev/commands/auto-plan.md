---
description: Create an execution plan without executing (dry run)
argument-hint: "<description of what you want>"
allowed-tools: ["Task", "Read", "Glob", "Grep", "Write", "AskUserQuestion"]
---

# Planning Mode Only

Follow PHASE 1-3 from the main /auto command:
1. Detect/load project profile
2. Understand requirements (ask questions)
3. Create detailed plan

DO NOT execute the plan. Stop after writing the plan file and getting user approval.

Output: "Plan created at .claude/plans/auto-{timestamp}.md - run /auto-execute to implement"
