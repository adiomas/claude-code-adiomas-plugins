---
name: auto-execute
description: Execute an existing plan
argument-hint: "[plan-file-path]"
allowed-tools: ["Task", "Bash", "Read", "Write", "Edit", "Glob", "Grep", "TodoWrite"]
---

# Execute Existing Plan

Execute PHASE 4-6 from an existing approved plan.

## CRITICAL: Use TodoWrite to Track Progress

Before starting, create todo list:
1. Find and validate plan
2. Phase 4: Execution (TDD)
3. Phase 5: Integration
4. Phase 6: Review and Verification

## STEP 1: FIND PLAN

### If argument provided:
Use the provided path directly.

### If no argument:
Search for most recent execution plan:

```bash
ls -t .claude/plans/auto-*.md 2>/dev/null | head -1
```

## STEP 2: VALIDATE PLAN LOCATION

**CRITICAL:** Execution plans MUST be at `.claude/plans/auto-*.md`

### Check 1: Plan exists at correct location

If plan found at `.claude/plans/auto-*.md`:
- Continue to Step 3

If NO plan found at `.claude/plans/auto-*.md`:

```
Error: No execution plan found.

Expected location: .claude/plans/auto-*.md

To create a plan:
1. Run /auto <description> - Full autonomous workflow
2. Run /auto-plan <description> - Planning only (dry run)

Once you have an approved plan, run /auto-execute to execute it.
```

### Check 2: Plan is not at wrong location

If plan exists at `docs/plans/` instead:

```
Error: Plan found at wrong location.

Found: docs/plans/{filename}.md
Expected: .claude/plans/auto-*.md

The file at docs/plans/ is likely a DESIGN DOCUMENT from the brainstorming phase,
NOT an execution plan.

Design documents describe WHAT to build.
Execution plans describe HOW to build (atomic tasks, dependencies, verification).

To fix:
1. Run /auto-plan <description> to create a proper execution plan
2. Or if this IS an execution plan, move it:
   mkdir -p .claude/plans
   mv docs/plans/{file}.md .claude/plans/auto-{timestamp}.md
```

## STEP 3: VALIDATE PLAN CONTENT

Read the plan and verify it has required sections:

**Required sections:**
- [ ] Tasks with dependencies
- [ ] Execution Strategy (parallel groups, sequential order)
- [ ] Verification Pipeline (commands for test, lint, typecheck)

**If missing sections:**

```
Error: Invalid execution plan format.

The plan at {path} is missing required sections:
- {missing section 1}
- {missing section 2}

A valid execution plan must have:
1. Tasks section with complexity, dependencies, files, verification criteria
2. Execution Strategy with parallel groups and sequential order
3. Verification Pipeline with test/lint/typecheck commands

Run /auto-plan to create a properly formatted plan.
```

## STEP 4: CHECK APPROVAL STATUS

Look for user approval marker in the plan or verify user approved it.

If not approved:

```
Warning: Plan may not be approved.

Before executing, please confirm you have reviewed and approved this plan.
Run /auto-plan to create a new plan with proper approval flow.

Continue anyway? (This will execute the plan)
```

## STEP 5: EXECUTE PHASE 4-6

### PHASE 4: EXECUTION

**MANDATORY:** Invoke `superpowers:test-driven-development` skill

For each task, follow TDD discipline:
1. **RED:** Write ONE minimal failing test FIRST
2. **GREEN:** Write ONLY enough code to pass
3. **REFACTOR:** Clean up while tests pass

**For Independent Tasks (Parallel):**

```
1. Create git worktree: git worktree add /tmp/auto-{id} -b auto/{id}
2. Dispatch task-executor agent to work in that worktree
3. Agent follows TDD cycle
4. Track progress in .claude/auto-progress.yaml
```

**For Dependent Tasks (Sequential):**

```
1. Check that dependency tasks are complete
2. Write failing test for this task (RED)
3. Implement minimal code (GREEN)
4. Verify (test/lint/typecheck)
5. If pass: refactor, commit, continue
```

**When Tests Fail:**
Invoke `superpowers:systematic-debugging` skill
- NO random fixes
- 4-phase protocol: Investigation -> Analysis -> Hypothesis -> Implementation
- Max 3 fix attempts, then escalate

### PHASE 5: INTEGRATION

After all tasks complete:

1. **Checkout base branch**
2. **Merge each task branch** in dependency order:
   ```bash
   git merge --no-ff auto/task-1 -m "feat: Create User model"
   ```
3. **Handle conflicts:**
   - Simple conflicts: resolve automatically
   - Complex conflicts: ask user for guidance
4. **Run full verification pipeline**
5. **Clean up worktrees:**
   ```bash
   git worktree remove /tmp/auto-task-1
   git branch -d auto/task-1
   ```

### PHASE 6: REVIEW

**MANDATORY:** Invoke `superpowers:verification-before-completion` skill

#### 6.1 Verification (NO CLAIMS WITHOUT EVIDENCE)

Follow the Gate Function:
1. **IDENTIFY:** What command proves this claim?
2. **RUN:** Execute FULL command (fresh, not cached)
3. **READ:** Full output, check exit code
4. **VERIFY:** Does output confirm the claim?
5. **ONLY THEN:** Make the claim

**Red Flags - NEVER say:**
- "Tests should pass" -> Run them and show output
- "Build probably works" -> Run build and show exit code
- "I think lint is clean" -> Run linter and show 0 errors

#### 6.2 Code Review

Invoke `superpowers:requesting-code-review` skill
Dispatch code-reviewer subagent to catch issues before completion.

#### 6.3 Present Results

1. **Summary of changes:**
   - Files created/modified
   - Lines added/removed
   - Tests added
2. **Verification evidence (ACTUAL output):**
   - Test results with counts
   - Lint output showing 0 errors
   - Build output showing success
3. **Ask for feedback:**
   "Everything is implemented and verified. Would you like me to:
   A) Create a PR
   B) Make adjustments (describe what)
   C) Show more details about specific changes"

## COMPLETION

Output `<promise>AUTO_COMPLETE</promise>` ONLY when ALL of these are true:
- All tasks implemented
- All verification passing (tests, lint, types, build)
- All branches merged
- User has approved the result

If ANY of these are false, DO NOT output the completion promise.
Continue working or ask for help.

## Extended Thinking Guidance (Opus 4.5)

This workflow is optimized for extended thinking models:

1. **Validate plan location FIRST** - Don't assume path is correct
2. **Use TodoWrite for ALL phases** - Track every step
3. **Run fresh verification** - Never rely on cached results
4. **Explicit evidence** - Show actual command output
5. **No assumptions** - Verify every claim with tool calls

### Thinking Points
- Before Phase 4: Is plan at correct location? Is it properly formatted?
- During Phase 4: Am I following TDD discipline for each task?
- Before Phase 6: Have I actually run ALL verification commands?
- Before completion: Do I have EVIDENCE for every claim?
