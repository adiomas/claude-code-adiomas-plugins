---
name: auto-prepare
description: |
  Prepare for autonomous execution - interactive planning phase.
  Use this when you want to plan interactively, then execute autonomously in a separate session.
  Creates all necessary state files for /auto-execute to continue the work.
argument-hint: "<description of what you want to build/fix/change>"
allowed-tools: ["Task", "Bash", "Read", "Write", "Edit", "Glob", "Grep", "TodoWrite", "AskUserQuestion"]
---

# Prepare for Autonomous Execution

This command implements the **Two-Agent Pattern** recommended by Anthropic:
1. **This session (Initializer):** Interactive planning with user input
2. **Next session (Coding Agent):** Autonomous execution from prepared state

## Why This Approach?

From Anthropic's research:
- "Each new session begins with no memory of what came before"
- Planning consumes context that could be used for coding
- Separating planning from execution gives coding agents a fresh context
- `next-session.md` provides minimal bootstrap context for new sessions

## CRITICAL: Use TodoWrite to Track All Phases

Before starting, create todo list:
1. Phase 1: Project Detection + Work Type Classification
2. Phase 2: Requirement Understanding (brainstorming) - INTERACTIVE
3. Phase 3: Planning (writing-plans) - INTERACTIVE with USER APPROVAL
4. Phase 4: Task Decomposition
5. Phase 5: Execution Prep (create state files)

Mark each phase in_progress when starting, completed when done.

---

## PHASE 1: PROJECT UNDERSTANDING

### 1.1 Project Detection
1. Check if `.claude/project-profile.yaml` exists
2. If NOT exists:
   - Invoke project-detector skill
   - Analyze: package.json, pyproject.toml, go.mod, Cargo.toml, etc.
   - Detect: test command, lint command, build command, framework
   - Detect database provider (Supabase, Firebase, Prisma, etc.)
   - Create `.claude/project-profile.yaml`
3. Load and display the project profile

### 1.2 Work Type Classification
**Invoke work-type-classifier skill**

1. Analyze user's request for keywords:
   - Frontend: "UI", "component", "page", "React", "CSS"
   - Backend: "API", "endpoint", "database", "server"
   - Docs: "documentation", "README", "spec"

2. Create `.claude/auto-context.yaml` with work type and required skills

### CHECKPOINT 1
Before Phase 2:
- [ ] `.claude/project-profile.yaml` exists
- [ ] `.claude/auto-context.yaml` exists
- [ ] TodoWrite shows Phase 1 completed

---

## PHASE 2: REQUIREMENT UNDERSTANDING (INTERACTIVE)

**CRITICAL: This phase is INTERACTIVE - engage the user!**

### 2.1 Invoke Brainstorming Skill
```
Use the Skill tool with skill: "superpowers:brainstorming"
```

The skill will guide you to:
1. **Ask ONE question at a time** - Never multiple questions
2. **Prefer multiple choice** when options are clear
3. **Apply YAGNI ruthlessly** - Remove unnecessary features
4. **Explore alternatives** before settling on approach

### 2.2 Domain-Specific Skills

Based on `.claude/auto-context.yaml`:

**If FRONTEND:** Also invoke `frontend-design` skill
**If BACKEND:** Also invoke `architecture-patterns` skill

### 2.3 Completion Criteria

Continue until you have:
- Clear scope definition
- Success criteria
- Any constraints or preferences
- User confirmation: "Yes, that's what I want"

**Save design document to:** `docs/plans/YYYY-MM-DD-<topic>-design.md`

### CHECKPOINT 2
Before Phase 3:
- [ ] Design doc exists at `docs/plans/`
- [ ] User confirmed requirements
- [ ] TodoWrite shows Phase 2 completed

---

## PHASE 3: PLANNING (INTERACTIVE with APPROVAL)

**CRITICAL: User MUST approve the plan before we save it**

### 3.1 Invoke Writing-Plans Skill
```
Use the Skill tool with skill: "superpowers:writing-plans"
```

### 3.2 Create Execution Plan

Write plan with this structure:

```markdown
# Execution Plan: {title}

## Summary
{one paragraph description}

## Tasks

### Task 1: {name}
- **Complexity:** S/M/L
- **Dependencies:** none | [task ids]
- **Files to modify:** {list}
- **Verification:** {what passes = done}

### Task 2: ...

## Execution Strategy
- Parallel group 1: [task 1, task 3] (independent)
- Sequential: [task 2] (depends on task 1)

## Verification Pipeline
1. Type check: {command}
2. Lint: {command}
3. Test: {command}
4. Build: {command}
```

### 3.3 Get User Approval

**MANDATORY:** Present the plan and ask:
```
"Here's my execution plan. Please review:
1. Are the tasks correct?
2. Is the execution strategy right?
3. Any changes needed?

Once you approve, I'll prepare everything for autonomous execution."
```

**Wait for explicit approval before proceeding!**

### 3.4 Save Approved Plan

Save to: `.claude/plans/auto-{timestamp}.md`

### CHECKPOINT 3
Before Phase 4:
- [ ] User approved the plan
- [ ] Plan saved to `.claude/plans/auto-*.md`
- [ ] TodoWrite shows Phase 3 completed

---

## PHASE 4: TASK DECOMPOSITION

### 4.1 Use Task Decomposer
Invoke task-decomposer skill to create atomic tasks.

### 4.2 Create Feature List (JSON format)

**Anthropic recommends JSON over Markdown** - "resists model manipulation better"

Create `.claude/auto-execution/tasks.json`:

```json
{
  "version": "1.0",
  "feature": "{feature-name-slug}",
  "plan_file": ".claude/plans/auto-{timestamp}.md",
  "created_at": "{ISO timestamp}",
  "created_by": "auto-prepare",
  "tasks": [
    {
      "id": "task-1",
      "name": "Create User model",
      "description": "Full description of what to do",
      "files": ["src/models/user.ts", "src/models/user.test.ts"],
      "dependencies": [],
      "verification_command": "npm test -- user.test.ts",
      "expected_output": "Tests: X passed, 0 failed",
      "complexity": "S",
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "evidence": null
    }
  ],
  "execution_strategy": {
    "mode": "parallel|sequential",
    "groups": [
      {"group": 1, "tasks": ["task-1", "task-3"], "parallel": true},
      {"group": 2, "tasks": ["task-2"], "parallel": false, "depends_on": 1}
    ]
  }
}
```

### CHECKPOINT 4
Before Phase 5:
- [ ] `.claude/auto-execution/tasks.json` created
- [ ] All tasks have verification commands
- [ ] Execution strategy defined
- [ ] TodoWrite shows Phase 4 completed

---

## PHASE 5: EXECUTION PREP

### 5.1 Create State File

Create `.claude/auto-execution/state.yaml`:

```yaml
version: "1.0"
status: ready_for_execution  # ready_for_execution | in_progress | completed | stuck
mode: overnight  # can be changed by --overnight flag
feature: "{feature-name}"
plan_file: ".claude/plans/auto-{timestamp}.md"
tasks_file: ".claude/auto-execution/tasks.json"
created_at: "{ISO timestamp}"
current_task: null
current_group: 1
total_groups: N
verification:
  test_command: "{from project-profile}"
  lint_command: "{from project-profile}"
  build_command: "{from project-profile}"
session_history: []
```

### 5.2 Create Progress File

Create `.claude/auto-execution/progress.md`:

```markdown
# Feature: {feature name}

## Progress: 0/{N} tasks complete (0%)

### Status: Ready for Execution

Prepared by `/auto-prepare` at {timestamp}
Plan: .claude/plans/auto-{timestamp}.md

### Pending Tasks
- [ ] task-1: {name}
- [ ] task-2: {name}
...

### Verification History
| Timestamp | Tests | Lint | Build | Notes |
|-----------|-------|------|-------|-------|
| (none yet) | - | - | - | - |
```

### 5.3 Create Next-Session Bootstrap

**CRITICAL: This file enables fast context bootstrap for coding agents**

Create `.claude/auto-execution/next-session.md`:

```markdown
# Next Session Context

## Quick Start
You are continuing autonomous execution prepared by `/auto-prepare`.
Run `/auto-execute` or `/auto-execute --overnight` to continue.

## Current State
- Status: Ready for execution
- Next task: task-1 ({task name})
- Tasks remaining: {N}
- All verification currently: N/A (not started)

## Key Decisions Made During Planning
{List important decisions from brainstorming phase}
- Decision 1: {what and why}
- Decision 2: {what and why}

## Project Context
- Framework: {from project-profile}
- Test runner: {command}
- Database: {if any}

## Files to Focus On
{List the main files that will be created/modified}
- src/models/user.ts (create)
- src/api/auth.ts (create)

## Gotchas / Learnings
{Any project-specific quirks discovered during planning}
- Uses Vitest, not Jest
- Database is Supabase

## Execution Instructions
1. Read state.yaml for current status
2. Read tasks.json for task details
3. Start with first pending task
4. Follow TDD: RED → GREEN → REFACTOR
5. Update tasks.json after each task
6. Update progress.md for human readability
7. Update this file with any new learnings
```

### 5.4 Create Git Branch

```bash
# Get feature name slug
FEATURE_SLUG=$(echo "{feature}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BRANCH_NAME="auto/${FEATURE_SLUG}-${TIMESTAMP}"

# Create and checkout branch
git checkout -b "$BRANCH_NAME"

# Initial commit with preparation files
git add .claude/auto-execution/
git commit -m "chore: prepare autonomous execution for ${FEATURE_SLUG}

Created by /auto-prepare
Plan: .claude/plans/auto-*.md
Tasks: $(cat .claude/auto-execution/tasks.json | jq '.tasks | length') tasks

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### 5.5 Output Completion Message

```
═══════════════════════════════════════════════════════════════════
 ✅ PREPARATION COMPLETE
═══════════════════════════════════════════════════════════════════

 Plan:     .claude/plans/auto-{timestamp}.md
 Tasks:    .claude/auto-execution/tasks.json ({N} tasks)
 Branch:   auto/{feature-slug}

 State files created:
   • state.yaml        - Execution state
   • tasks.json        - Task list with dependencies
   • progress.md       - Human-readable progress
   • next-session.md   - Context for next session

═══════════════════════════════════════════════════════════════════
 NEXT STEPS
═══════════════════════════════════════════════════════════════════

 To execute, START A NEW SESSION and run:

   /auto-execute              # Interactive execution
   /auto-execute --overnight  # Autonomous overnight execution

 The new session will:
   1. Read next-session.md for fast context bootstrap
   2. Execute tasks following TDD discipline
   3. Checkpoint after each task
   4. Handle context limits with auto-restart

═══════════════════════════════════════════════════════════════════
```

### CHECKPOINT 5 (FINAL)
- [ ] `.claude/auto-execution/state.yaml` exists
- [ ] `.claude/auto-execution/tasks.json` exists
- [ ] `.claude/auto-execution/progress.md` exists
- [ ] `.claude/auto-execution/next-session.md` exists
- [ ] Git branch created with initial commit
- [ ] Completion message displayed
- [ ] TodoWrite shows all phases completed

---

## State File Locations Summary

```
.claude/
├── project-profile.yaml     # Project detection results
├── auto-context.yaml        # Work type classification
├── plans/
│   └── auto-{timestamp}.md  # Approved execution plan
└── auto-execution/
    ├── state.yaml           # Machine-readable state
    ├── tasks.json           # Task list with status
    ├── progress.md          # Human-readable progress
    └── next-session.md      # Bootstrap context for next session
```

---

## Error Handling

### If user doesn't approve plan
- Ask what changes they want
- Revise plan
- Ask for approval again
- Do NOT proceed without approval

### If project detection fails
- Ask user for project details
- Create manual project-profile.yaml

### If work type unclear
- Default to FULLSTACK
- Apply both frontend and backend skills

---

## Why This Pattern Works

Based on Anthropic and Cursor research:

1. **Context Preservation**
   - Planning uses context for understanding
   - Execution starts fresh with minimal bootstrap
   - `next-session.md` provides just enough context

2. **Resilience**
   - If execution session crashes, state files persist
   - Can resume from any checkpoint
   - JSON format resists model errors

3. **User Control**
   - Plan approval before execution
   - Can review tasks.json before running
   - Can modify plan file manually if needed

4. **Optimal Bootstrap**
   - New session reads ~1KB of context (next-session.md)
   - vs ~50KB if we continued in same session
   - More room for actual coding work
