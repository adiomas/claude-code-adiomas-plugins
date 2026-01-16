---
description: Create an execution plan without executing (dry run)
argument-hint: "<description of what you want>"
allowed-tools: ["Task", "Read", "Glob", "Grep", "Write", "Edit", "AskUserQuestion", "TodoWrite"]
---

# Planning Mode (Dry Run)

Create a detailed execution plan WITHOUT executing it. This command runs PHASE 1-3 only.

## CRITICAL: Use TodoWrite to Track Progress

Before starting, create todo list with these items:
1. Phase 1: Project Detection + Work Type Classification
2. Phase 2: Requirement Understanding (brainstorming)
3. Phase 3: Planning (writing-plans)
4. Validate plan at correct location

Mark each phase in_progress when starting, completed when done.

## PHASE 1: PROJECT DETECTION + WORK TYPE CLASSIFICATION

### 1.1 Check/Create Project Profile

1. Check if `.claude/project-profile.yaml` exists
2. If NOT exists:
   - Run project-detector skill
   - Analyze: package.json, pyproject.toml, go.mod, Cargo.toml, etc.
   - Detect: test command, lint command, build command, framework
   - Create `.claude/project-profile.yaml`
3. Load and display the project profile to confirm understanding

### 1.2 Work Type Classification

1. Run work-type-classifier skill
2. Analyze user's request for keywords:
   - Frontend: "UI", "component", "page", "React", "CSS"
   - Backend: "API", "endpoint", "database", "server"
   - Documentation: "docs", "README", "spec"
3. Create `.claude/auto-context.yaml` with:
   - work_type
   - skills_to_invoke (discipline + domain_specific)

### CHECKPOINT 1
Verify before proceeding:
- [ ] `.claude/project-profile.yaml` exists
- [ ] `.claude/auto-context.yaml` exists
- [ ] TodoWrite shows Phase 1 completed

## PHASE 2: REQUIREMENT UNDERSTANDING

**MANDATORY:** Invoke `superpowers:brainstorming` skill

```
Use the Skill tool with skill: "superpowers:brainstorming"
```

### 2.1 Brainstorming Discipline

The brainstorming skill enforces:
1. **Ask ONE question at a time** - Never multiple questions
2. **Prefer multiple choice** when options are clear
3. **Apply YAGNI ruthlessly** - Remove unnecessary features
4. **Explore alternatives** before settling on approach
5. **Validate incrementally** - Get approval on each section

### 2.2 Domain-Specific Skills (Based on auto-context.yaml)

Read `.claude/auto-context.yaml` and invoke additional skills:

**If work_type == FRONTEND:**
```
Also invoke: frontend-design skill
```

**If work_type == BACKEND:**
```
Also invoke: architecture-patterns skill
```

### 2.3 Completion Criteria

Continue until you have:
- Clear scope definition
- Success criteria
- Any constraints or preferences
- User confirmation: "Yes, that's what I want"
- Design document at `docs/plans/YYYY-MM-DD-<topic>-design.md`

### CHECKPOINT 2
Verify before proceeding:
- [ ] Design doc exists at `docs/plans/YYYY-MM-DD-<topic>-design.md`
- [ ] User confirmed requirements
- [ ] TodoWrite shows Phase 2 completed

## PHASE 3: PLANNING

**MANDATORY:** Invoke `superpowers:writing-plans` skill

```
Use the Skill tool with skill: "superpowers:writing-plans"
```

### 3.1 Task Decomposition

Use task-decomposer skill to break down into atomic tasks:

1. **Analyze codebase** for relevant existing code
2. **Identify tasks** needed to complete the request
3. **Map dependencies** between tasks:
   - Independent tasks -> can run in parallel
   - Dependent tasks -> must run sequentially
4. **Assign verification** criteria per task
5. **Estimate complexity** (S/M/L) per task

### 3.2 Plan Structure

Write plan to `.claude/plans/auto-{timestamp}.md` with this structure:

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
- Parallel group 2: [task 4, task 5] (independent, after task 2)

## Verification Pipeline
1. Type check: {command}
2. Lint: {command}
3. Test: {command}
4. Build: {command} (if applicable)
```

### 3.3 Get User Approval

Present plan and ask:
"Here's my plan. Does this look right? Should I proceed?"

**DO NOT proceed without explicit user approval.**

### CHECKPOINT 3
Verify before completing:
- [ ] Execution plan exists at `.claude/plans/auto-{timestamp}.md`
- [ ] Plan has Tasks section with dependencies
- [ ] Plan has Execution Strategy section
- [ ] Plan has Verification Pipeline section
- [ ] User approved the plan
- [ ] TodoWrite shows Phase 3 completed

## FINAL VALIDATION

**CRITICAL:** Before completing, verify plan location:

```bash
ls .claude/plans/auto-*.md
```

**If execution plan is NOT at `.claude/plans/auto-*.md`:**
1. STOP
2. Move plan to correct location
3. Verify again

**Common mistake:** Saving plan to `docs/plans/` instead of `.claude/plans/`
- `docs/plans/` is for DESIGN DOCUMENTS (from brainstorming)
- `.claude/plans/auto-*.md` is for EXECUTION PLANS (from writing-plans)

## OUTPUT

After successful completion:

```
Plan created at .claude/plans/auto-{timestamp}.md

To execute this plan, run: /auto-execute

Files created:
- .claude/project-profile.yaml (if new)
- .claude/auto-context.yaml
- docs/plans/YYYY-MM-DD-<topic>-design.md (design document)
- .claude/plans/auto-{timestamp}.md (execution plan)
```

## Extended Thinking Guidance (Opus 4.5)

This workflow is optimized for extended thinking models:

1. **Use TodoWrite for ALL phases** - Create explicit todo per phase
2. **Think before each phase** - Consider edge cases
3. **Validate file locations** - Always verify paths exist
4. **Explicit checkpoints** - Mark phase complete before moving on
5. **No assumptions** - Verify every step with actual tool calls

### Thinking Points
- Before Phase 2: What clarifying questions are needed?
- Before Phase 3: Is the scope well-defined?
- Before completion: Is the plan at correct location?
