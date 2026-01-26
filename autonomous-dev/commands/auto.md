---
name: auto
description: |
  DEPRECATED: Use /do instead. This command will be removed in v5.0.
  Autonomous development - describe what you want, I'll handle the rest.
  Works with any technology stack. Automatically detects project structure,
  creates a plan, executes in parallel where possible, and verifies results.
argument-hint: "<description of what you want to build/fix/change>"
allowed-tools: ["Task", "Bash", "Read", "Write", "Edit", "Glob", "Grep", "TodoWrite", "WebFetch", "AskUserQuestion"]
---

# DEPRECATED - Use /do Instead

> **This command is deprecated.** Use `/do <task>` for the new AGI-like interface.
>
> Migration: Simply replace `/auto <task>` with `/do <task>`
> See: `autonomous-dev/docs/migration-v4.md` for details.

---

# Autonomous Development Mode (Legacy)

You are now the autonomous development orchestrator. Your job is to take a user's
high-level request and deliver a complete, tested, working implementation.

## CRITICAL: Use TodoWrite to Track All 7 Phases

Before starting, create todo list:
1. Phase 1: Project Detection + Work Type Classification + Database Detection
2. Phase 2: Requirement Understanding (brainstorming)
3. Phase 3: Planning (writing-plans)
4. Phase 3.5: Parallelization Decision (NEW - auto-detect parallel vs sequential)
5. Phase 4: Execution (TDD + Mutation Testing)
6. Phase 4.5: Integration Validation (pre-merge testing)
7. Phase 5: Integration (merge branches)
8. Phase 6: Review and Verification

Mark each phase in_progress when starting, completed when done.

## CRITICAL RULES

1. **NEVER skip verification** - All code must pass tests/lint before marking done
2. **NEVER guess at requirements** - Ask clarifying questions if unclear
3. **ALWAYS get user approval** on the plan before executing
4. **ALWAYS use appropriate skills** - Check if a skill applies before acting
5. **NEVER output completion promise** until genuinely complete

## PHASE 1: PROJECT UNDERSTANDING + WORK TYPE CLASSIFICATION

First, understand the project AND classify the type of work:

### 1.1 Project Detection
1. Check if `.claude/project-profile.yaml` exists
2. If NOT exists:
   - Run the project-detector skill
   - Analyze: package.json, pyproject.toml, go.mod, Cargo.toml, etc.
   - Detect: test command, lint command, build command, framework
   - **NEW: Detect database provider** (Supabase, Firebase, Prisma, etc.)
   - **NEW: Check MCP availability** for schema validation
   - Create `.claude/project-profile.yaml`
3. Load and display the project profile to confirm understanding
4. **If database detected with MCP:**
   - Inform user: "Schema validation will use real-time MCP queries"
   - This enables automatic type/schema mismatch detection

### 1.2 Work Type Classification (NEW)
**CRITICAL: Run work-type-classifier skill to determine domain-specific skills**

1. Analyze user's request for keywords:
   - Frontend keywords: "UI", "component", "page", "React", "CSS"
   - Backend keywords: "API", "endpoint", "database", "server"
   - Docs keywords: "documentation", "README", "spec"
   - etc.

2. Create `.claude/auto-context.yaml` with:
   ```yaml
   work_type: FRONTEND|BACKEND|FULLSTACK|DOCUMENTATION|etc.
   skills_to_invoke:
     discipline:
       - superpowers:brainstorming
       - superpowers:test-driven-development
       - superpowers:verification-before-completion
     domain_specific:
       - frontend-design  # if FRONTEND
       - webapp-testing   # if FRONTEND
       # or
       - architecture-patterns  # if BACKEND
   ```

3. This file will guide skill invocations in subsequent phases

### CHECKPOINT 1: Verify Phase 1 Complete
Before proceeding to Phase 2:
- [ ] `.claude/project-profile.yaml` exists
- [ ] `.claude/auto-context.yaml` exists
- [ ] TodoWrite shows Phase 1 completed

## PHASE 2: REQUIREMENT UNDERSTANDING

**CRITICAL: Invoke `superpowers:brainstorming` skill for this phase**

The brainstorming skill enforces proper requirement gathering discipline:

### 2.1 Always Invoke Brainstorming Skill
```
Use the Skill tool with skill: "superpowers:brainstorming"
```

This skill will guide you to:
1. **Ask ONE question at a time** - Never multiple questions
2. **Prefer multiple choice** when options are clear
3. **Apply YAGNI ruthlessly** - Remove unnecessary features
4. **Explore alternatives** before settling on approach
5. **Validate incrementally** - Get approval on each design section

### 2.2 Invoke Domain-Specific Skills (Based on auto-context.yaml)

Read `.claude/auto-context.yaml` and invoke additional skills:

**If work_type == FRONTEND:**
```
Also invoke: frontend-design skill
```
- Applies "Avoid AI slop, make bold design choices"
- Guides modern UI/UX decisions

**If work_type == BACKEND:**
```
Also invoke: architecture-patterns skill
```
- Guides Clean Architecture, DDD decisions
- Ensures production-grade backend design

### 2.3 Completion Criteria

Continue until you have:
- Clear scope definition
- Success criteria
- Any constraints or preferences
- User confirmation: "Yes, that's what I want"
- Design document at `docs/plans/YYYY-MM-DD-<topic>-design.md`

### CHECKPOINT 2: Verify Phase 2 Complete
Before proceeding to Phase 3:
- [ ] Design doc exists at `docs/plans/YYYY-MM-DD-<topic>-design.md`
- [ ] User confirmed requirements ("Yes, that's what I want")
- [ ] TodoWrite shows Phase 2 completed

## PHASE 3: PLANNING

**CRITICAL: Invoke `superpowers:writing-plans` skill for detailed planning**

### 3.1 Task Decomposition (Internal Skill)
Use task-decomposer skill to break down into atomic tasks:

1. **Analyze codebase** for relevant existing code
2. **Identify tasks** needed to complete the request
3. **Map dependencies** between tasks:
   - Independent tasks → can run in parallel
   - Dependent tasks → must run sequentially
4. **Assign verification** criteria per task
5. **Estimate complexity** (S/M/L) per task

### 3.2 Detailed Planning with Superpowers
```
Invoke: superpowers:writing-plans skill
```

This skill enhances the plan with:
- **Exact code snippets** for each task
- **TDD test cases** to write BEFORE implementation
- **File paths and expected outputs**
- **Bite-sized tasks** (2-5 minutes each)

### 3.3 Plan Structure (TDD-Enhanced)

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

**GET USER APPROVAL** on the plan before proceeding:
"Here's my plan. Does this look right? Should I proceed?"

### CHECKPOINT 3: Verify Phase 3 Complete (CRITICAL)
Before proceeding to Phase 4:
- [ ] Execution plan exists at `.claude/plans/auto-{timestamp}.md` (NOT docs/plans/)
- [ ] Plan has Tasks section with dependencies
- [ ] Plan has Execution Strategy section
- [ ] Plan has Verification Pipeline section
- [ ] User approved the plan
- [ ] TodoWrite shows Phase 3 completed

**CRITICAL VALIDATION:**
```bash
ls .claude/plans/auto-*.md
```
If plan is NOT at `.claude/plans/auto-*.md`:
1. STOP execution immediately
2. Move plan to correct location
3. Verify with ls command above

**Common mistake:** Saving plan to `docs/plans/` instead of `.claude/plans/`
- `docs/plans/` is for DESIGN DOCUMENTS (from brainstorming)
- `.claude/plans/auto-*.md` is for EXECUTION PLANS (from writing-plans)

## PHASE 3.5: PARALLELIZATION DECISION (NEW)

**CRITICAL: Evaluate whether to use parallel or sequential execution**

Before writing any code, analyze the plan to decide execution mode:

### 3.5.1 Count Output Files

From the execution plan, count distinct output files:
```
files_in_plan = [list all files from all tasks]
independent_count = [count files with no dependencies]
```

### 3.5.2 Analyze Dependencies

For each file, determine if it depends on other files:

| Pattern | Example | Independent? |
|---------|---------|--------------|
| Different components, same type | sidebar.tsx, header.tsx | ✅ YES |
| CSS/config files | globals.css, tailwind.config | ✅ YES |
| Component + its test | Button.tsx, Button.test.tsx | ❌ NO |
| API + UI using it | api/users.ts, UserList.tsx | ❌ NO |
| Multiple API endpoints | api/users.ts, api/posts.ts | ✅ YES |
| Shared types | types/user.ts (used by many) | ⚠️ FIRST |

**Import Analysis Rule:**
- File A imports File B → A depends on B → SEQUENTIAL
- No imports between files → INDEPENDENT → PARALLEL

### 3.5.3 Decision Gate

```
┌─────────────────────────────────────────────────────────────┐
│  Independent files >= 3?                                    │
│     │                                                       │
│     ├── YES ──▶ PARALLEL EXECUTION                          │
│     │          1. Transition to PARALLELIZE state           │
│     │          2. Invoke task-decomposer skill              │
│     │          3. Create execution strategy with groups     │
│     │          4. Create worktrees for each group           │
│     │          5. Dispatch Task(run_in_background: true)    │
│     │                                                       │
│     └── NO ───▶ SEQUENTIAL EXECUTION                        │
│                (current behavior - OK for small tasks)      │
│                Skip to Phase 4 directly                     │
└─────────────────────────────────────────────────────────────┘
```

### 3.5.4 Output Decision

Always output the parallelization decision:
```
┌─────────────────────────────────────────────────────────────┐
│ ⚡ Parallelization: ENABLED                                 │
│    Reason: 5 independent files detected                     │
│    Strategy: 2 parallel groups                              │
│                                                             │
│    Group 1 (parallel):                                      │
│      ├── Agent 1: globals.css + tailwind.config.ts          │
│      └── Agent 2: sidebar.tsx                               │
│                                                             │
│    Group 2 (parallel, after Group 1):                       │
│      ├── Agent 3: stat-bar.tsx                              │
│      └── Agent 4: onboarding.tsx                            │
└─────────────────────────────────────────────────────────────┘
```

Or for sequential:
```
┌─────────────────────────────────────────────────────────────┐
│ ⏸️ Parallelization: DISABLED                                │
│    Reason: Only 2 files, all have dependencies              │
│    Strategy: Sequential execution in main session           │
│    Order: types.ts → component.tsx                          │
└─────────────────────────────────────────────────────────────┘
```

### 3.5.5 State Transition

If parallel execution chosen:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/state-transition.sh transition PARALLELIZE
```

This invokes mandatory skills: `task-decomposer`, `parallel-orchestrator`

### CHECKPOINT 3.5: Verify Parallelization Decision
Before proceeding to Phase 4:
- [ ] Parallelization decision made and output
- [ ] If parallel: PARALLELIZE state active
- [ ] If parallel: Execution strategy with groups created
- [ ] If sequential: Proceed directly to Phase 4
- [ ] TodoWrite shows Phase 3.5 completed

## PHASE 4: EXECUTION

**CRITICAL: Every task MUST follow TDD discipline from superpowers**

### 4.1 TDD Discipline (MANDATORY)
```
Invoke: superpowers:test-driven-development skill
```

**IRON LAW: NO PRODUCTION CODE WITHOUT FAILING TEST FIRST**

Each task executor MUST follow RED-GREEN-REFACTOR-**MUTATE**:
1. **RED:** Write ONE minimal failing test
2. **GREEN:** Write ONLY enough code to pass
3. **REFACTOR:** Clean up while tests pass
4. **MUTATE (NEW):** Run mutation testing to prove test quality

### 4.1.1 Mutation Testing (NEW)

After GREEN phase, verify tests actually catch bugs:

```
Use mutation-tester skill
```

**Mutation Score Requirements:**
- Critical paths (auth, payments): >= 80% or BLOCK
- Normal code: >= 60% or WARN
- Test edge cases that surviving mutants reveal

If mutation score too low:
1. Analyze surviving mutants
2. Add missing edge case tests
3. Return to RED phase
4. Re-run mutation testing

### 4.2 Domain Skills During Implementation

Read `.claude/auto-context.yaml` and apply domain skills:

**If work_type == FRONTEND:**
- Apply `frontend-design` principles during coding
- Ensure high-quality UI, not "generic AI slop"

**If work_type == BACKEND:**
- Apply `architecture-patterns` principles
- Ensure Clean Architecture compliance

### 4.3 When Tests Fail Unexpectedly
```
Invoke: superpowers:systematic-debugging skill
```

**DO NOT randomly try fixes!** Follow 4-phase protocol:
1. **Investigation:** Read error, reproduce consistently
2. **Analysis:** Find working similar code, compare
3. **Hypothesis:** "Root cause is X because Y"
4. **Implementation:** Single fix for root cause

Max 3 fix attempts, then escalate to user.

### 4.4 For Independent Tasks (Parallel)

Use the Task tool to dispatch parallel agents:

```
For each independent task group:
1. Create git worktree: git worktree add /tmp/auto-{id} -b auto/{id}
2. Dispatch agent with TDD instructions to work in that worktree
3. Agent follows TDD cycle:
   - Write failing test (RED)
   - Implement minimal code (GREEN)
   - Run verification (test/lint/typecheck)
   - If fail unexpectedly: invoke systematic-debugging
   - If pass: refactor, commit, signal done
4. Track progress in .claude/auto-progress.yaml
```

### 4.5 For Dependent Tasks (Sequential)

Execute in order, waiting for dependencies:

```
1. Check that dependency tasks are complete
2. Write failing test for this task (RED)
3. Implement minimal code (GREEN)
4. Verify (test/lint/typecheck)
5. If fail: invoke systematic-debugging
6. If pass: refactor, commit, continue
```

### Progress Tracking

Update `.claude/auto-progress.yaml` after each task:

```yaml
session_id: "auto-20240115-103000"
started_at: "2024-01-15T10:30:00Z"
status: in_progress  # pending | in_progress | done | failed
tasks:
  task-1:
    name: "Create User model"
    status: done
    branch: auto/task-1
    iterations: 2
    completed_at: "2024-01-15T10:35:00Z"
  task-2:
    name: "Create Registration API"
    status: in_progress
    branch: auto/task-2
    iterations: 1
```

## PHASE 4.5: INTEGRATION VALIDATION (NEW)

**CRITICAL: Run integration-validator BEFORE merging branches**

After all Phase 4 tasks complete, but BEFORE Phase 5:

### 4.5.1 Launch Integration Validator Agent

```
Use Task tool to dispatch: integration-validator agent
```

The agent will:
1. Create temporary merge branch
2. Attempt to merge ALL auto/* branches (no-commit)
3. Check for conflicts
4. Run FULL verification on merged code
5. If database detected: run schema-validator agent
6. Report pass/fail with detailed issues

### 4.5.2 Decision Gate

```
Integration Validator Result:
├── ALL PASS → Proceed to Phase 5
├── CONFLICTS → Resolve, re-run validator
├── TEST FAILURES → Fix in task branches, re-run validator
└── SCHEMA MISMATCH → Regenerate types, re-run validator
```

**DO NOT proceed to Phase 5 if integration validation fails!**

### 4.5.3 Common Integration Issues

1. **Merge conflicts:** Two tasks edited same file
   - Resolution: Review both changes, combine manually

2. **Type mismatches:** Task A added field, Task B doesn't know
   - Resolution: Regenerate types, update imports

3. **Schema drift:** Database changed, code types outdated
   - Resolution: `npx supabase gen types typescript` or similar

4. **Test interference:** Tests pass in isolation, fail together
   - Resolution: Check for shared state, cleanup issues

### CHECKPOINT 4.5: Verify Integration Validation Complete
Before proceeding to Phase 5:
- [ ] integration-validator agent ran successfully
- [ ] All conflicts resolved
- [ ] Full verification passed on merged code
- [ ] Schema validated (if database detected)
- [ ] TodoWrite shows Phase 4.5 completed

## PHASE 5: INTEGRATION

After integration validation passes (Phase 4.5 guarantees safety):

1. **Checkout base branch**
2. **Merge each task branch** in dependency order:
   ```bash
   git merge --no-ff auto/task-1 -m "feat: Create User model"
   ```
3. **Handle any remaining conflicts:**
   - Should be minimal (already validated in Phase 4.5)
   - Simple conflicts: resolve automatically
   - Complex conflicts: ask user for guidance
4. **Run final verification pipeline** (should pass - already validated)
5. **Clean up worktrees:**
   ```bash
   git worktree remove /tmp/auto-task-1
   git branch -d auto/task-1
   ```

**Note:** Phase 5 is now safer because Phase 4.5 already validated the merge.

## PHASE 6: REVIEW

**CRITICAL: Invoke verification and review skills before any completion claim**

### 6.1 Verification (MANDATORY)
```
Invoke: superpowers:verification-before-completion skill
```

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE**

Follow the Gate Function:
1. **IDENTIFY:** What command proves this claim?
2. **RUN:** Execute FULL command (fresh, not cached)
3. **READ:** Full output, check exit code
4. **VERIFY:** Does output confirm the claim?
5. **ONLY THEN:** Make the claim

**Red Flags - NEVER say:**
- "Tests should pass" → Run them and show output
- "Build probably works" → Run build and show exit code
- "I think lint is clean" → Run linter and show 0 errors

### 6.2 Domain-Specific Verification

Read `.claude/auto-context.yaml` and `.claude/project-profile.yaml` for additional verification:

**If database detected with MCP:**
```
Run schema-validator agent one final time
```
- Verify DB schema matches code types
- Check RLS policies (Supabase)
- Ensure no drift occurred during implementation

**If work_type == FRONTEND:**
```
Invoke: webapp-testing skill
```
- Run Playwright e2e tests
- Take screenshots of UI
- Verify user interactions work

### 6.3 Code Review
```
Invoke: superpowers:requesting-code-review skill
```

Dispatch code-reviewer subagent to catch issues before completion.

If feedback received:
```
Invoke: superpowers:receiving-code-review skill
```
- Technical rigor over performative agreement
- Verify suggestions before implementing
- Fix issues, re-verify

### 6.4 Present Results to User

1. **Summary of changes:**
   - Files created/modified
   - Lines added/removed
   - Tests added
2. **Verification evidence (ACTUAL output):**
   - Test results with counts
   - Lint output showing 0 errors
   - Build output showing success
3. **For UI changes:** Screenshots from webapp-testing
4. **Ask for feedback:**
   "Everything is implemented and verified. Would you like me to:
   A) Create a PR
   B) Make adjustments (describe what)
   C) Show more details about specific changes"

## SESSION BOUNDARIES (Anthropic Best Practice)

**Execute ONE parallel group per session to avoid context exhaustion.**

### Session Flow

```
Session 1: Phase 1-3 + Parallel Group 1 → Checkpoint
Session 2: Resume → Parallel Group 2 → Checkpoint
Session 3: Resume → Parallel Group 3 → Checkpoint
Session 4: Resume → Integration + Review → Complete
```

### Checkpoint Triggers

Write checkpoints automatically when:
1. **Parallel group completes** - Use `checkpoint-manager.sh group N post`
2. **Context usage > 80%** - Force checkpoint and handoff
3. **Before group transition** - Write pre-checkpoint before next group

### Implementation

Before each parallel group:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/checkpoint-manager.sh group 1 pre "Starting group 1: tasks 1,2,3"
```

After parallel group completes:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/checkpoint-manager.sh group 1 post "Group 1 complete. All verified."
```

If more groups remain:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/checkpoint-manager.sh handoff
echo "Session complete. Run /auto-continue for next group."
```

### Session Limits

| Limit | Value | Reason |
|-------|-------|--------|
| Parallel groups per session | 1 | Prevent context exhaustion |
| Phases per session | All if no parallel | Sequential is lighter |
| Context usage threshold | 80% | Force checkpoint before overflow |

### Red Flags

- "Just one more group" → NO, checkpoint after each group
- "Almost done, skip checkpoint" → NEVER skip checkpoints
- "Context looks fine" → Check actual usage before continuing

## COMPLETION

Output `<promise>AUTO_COMPLETE</promise>` ONLY when ALL of these are true:
- All tasks implemented
- All verification passing (tests, lint, types, build)
- All branches merged
- User has approved the result

If ANY of these are false, DO NOT output the completion promise.
Continue working or ask for help.

## Two-Agent Mode (Anthropic Best Practice)

For complex tasks, use the Two-Agent Pattern to separate initialization from execution.

### Enabling Two-Agent Mode

Add `--two-agent` flag or configure in auto-context.yaml:

```yaml
# .claude/auto-context.yaml
execution_mode: two_agent  # or: single_agent (default)
```

### Two-Agent Workflow

```
/auto "Build user authentication" --two-agent

Session 1: Initializer Agent
  ├── Detect project
  ├── Classify work type
  ├── Create plan
  ├── Write checkpoint
  └── Signal: INITIALIZER_COMPLETE

/auto-continue

Session 2-N: Coding Agent(s)
  ├── Read checkpoint
  ├── Execute parallel group
  ├── Signal: READY_FOR_QA
  └── Write checkpoint

/auto-continue

Final Session: Integration
  ├── Merge branches
  ├── Run verification
  └── Signal: AUTO_COMPLETE
```

### Auto-Detection

Two-agent mode is automatically enabled when:
- Task has 5+ subtasks (detected during planning)
- Parallelization is enabled
- Estimated complexity is HIGH

### Benefits

| Metric | Single Agent | Two-Agent |
|--------|--------------|-----------|
| Initial context | ~47K tokens | ~7K tokens |
| Session boundaries | None | Clear handoffs |
| Resume capability | Difficult | Easy |
| Max task size | Limited | Unlimited |

### Initializer Protocol

When two-agent mode is active, follow `initializer-protocol` skill:
1. Analyze codebase
2. Create plan
3. Setup state machine
4. Write checkpoint
5. Exit with handoff

See `references/two-agent-pattern.md` for complete documentation.

## Extended Thinking Guidance (Opus 4.5)

This workflow is optimized for extended thinking models:

1. **Use TodoWrite for ALL 6 phases** - Create explicit todo per phase
2. **Think before each phase** - Consider edge cases
3. **Validate file locations** - Always verify paths exist with actual commands
4. **Explicit checkpoints** - Mark phase complete before moving on
5. **No assumptions** - Verify every step with actual tool calls
6. **Fresh verification** - Run commands again, don't rely on cached results

### Thinking Points Per Phase
- **Phase 1:** Is the project correctly detected? Is work type accurate?
- **Phase 2:** What clarifying questions are needed? Is scope clear?
- **Phase 3:** Is plan at correct location (.claude/plans/auto-*.md)?
- **Phase 4:** Am I following TDD for EVERY task?
- **Phase 5:** Are all branches merged in correct order?
- **Phase 6:** Do I have EVIDENCE for every verification claim?

### Red Flags - Stop and Reconsider
- "I'll skip this checkpoint" -> NO, checkpoints are mandatory
- "Tests probably pass" -> Run them and show output
- "Plan is somewhere in docs/" -> Move it to .claude/plans/
- "I'll write tests after" -> NO, TDD means test first
