---
name: auto-execute
description: |
  Execute a prepared autonomous plan.
  Supports --overnight for fully autonomous execution, --continue for resuming.
  Reads state from .claude/auto-execution/ created by /auto-prepare.
argument-hint: "[--overnight] [--continue] [plan-file-path]"
allowed-tools: ["Task", "Bash", "Read", "Write", "Edit", "Glob", "Grep", "TodoWrite"]
---

# Execute Prepared Plan

Execute tasks from a prepared autonomous plan. This command implements the
"Coding Agent" role in Anthropic's Two-Agent Pattern.

## Arguments

Parse from `$ARGUMENTS`:

- **`--overnight`**: Run in overnight mode (no permission prompts, auto-restart)
- **`--continue`**: Resume from checkpoint (reads session history)
- **plan-file-path**: Optional explicit path to plan file

## Execution Modes

| Mode | Triggered By | Permissions | Context Limit |
|------|--------------|-------------|---------------|
| Interactive | No flags | Normal prompts | Manual handoff |
| Overnight | `--overnight` | Auto-accept | Auto-restart |
| Continue | `--continue` | From state | Resume from checkpoint |

---

## PHASE 0: BOOTSTRAP

**ALWAYS run first - invoke execution-bootstrap skill**

### 0.1 Check for Prepared State

```bash
# Check if prepared by /auto-prepare
if [[ -f .claude/auto-execution/state.yaml ]]; then
  echo "Found prepared execution state"
  MODE="prepared"
else
  echo "No prepared state found, looking for plan file..."
  MODE="legacy"
fi
```

### 0.2 Prepared Mode Bootstrap (Preferred)

If `.claude/auto-execution/` exists:

1. **Read next-session.md FIRST** (fast context bootstrap)
   - Current state summary
   - Key decisions
   - Gotchas/learnings
   - Next steps

2. **Read state.yaml** (machine state)
   - Status, current task, verification commands

3. **Read tasks.json** (task details)
   - Find first `status: "pending"` task

4. **Validate state**

   | Status | Action |
   |--------|--------|
   | `ready_for_execution` | Start from first task |
   | `in_progress` | Resume from `current_task` |
   | `completed` | All done, run final verification |
   | `stuck` | Read stuck-report, ask user |

5. **Run initial verification**
   ```bash
   # Ensure we're starting clean
   npm test && npm run lint
   ```

6. **Output bootstrap summary**

### 0.3 Legacy Mode Bootstrap

If no prepared state (backwards compatibility):

1. Find plan file:
   ```bash
   ls -t .claude/plans/auto-*.md 2>/dev/null | head -1
   ```

2. Validate plan location and content

3. Create minimal state tracking:
   ```bash
   mkdir -p .claude/auto-execution
   # Create state.yaml from plan
   ```

### CHECKPOINT 0
Before proceeding:
- [ ] State files exist and are valid
- [ ] Current task identified
- [ ] Initial verification passed
- [ ] Bootstrap summary displayed

---

## PHASE 1: EXECUTION LOOP

**MANDATORY: Invoke `superpowers:test-driven-development` skill**

### 1.1 Task Execution Protocol

For each task:

```
┌─────────────────────────────────────────────────────────────────┐
│ TASK EXECUTION LOOP                                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Update state: current_task = task.id                       │
│     └── state.yaml: status = in_progress                       │
│                                                                 │
│  2. Check dependencies complete                                 │
│     └── All tasks in dependencies[] have status: "done"        │
│                                                                 │
│  3. TDD Cycle (RED → GREEN → REFACTOR)                         │
│     ├── RED: Write ONE failing test                            │
│     ├── GREEN: Write MINIMAL code to pass                      │
│     └── REFACTOR: Clean up while green                         │
│                                                                 │
│  4. Verify task                                                 │
│     └── Run task.verification_command                          │
│     └── Check output matches task.expected_output              │
│                                                                 │
│  5. If FAIL → invoke superpowers:systematic-debugging          │
│     └── Follow 4-phase: Investigate → Analyze → Hypothesis → Fix│
│     └── Max 3 attempts per task                                │
│                                                                 │
│  5.5 If STILL FAIL → invoke rollback-manager skill             │
│     └── Auto-rollback to last checkpoint                       │
│     └── Save failure evidence                                  │
│     └── Decide: retry with pivot | skip | abort                │
│                                                                 │
│  6. If PASS → complete task                                    │
│     ├── Update tasks.json: status = "done", evidence = output  │
│     ├── Update progress.md                                     │
│     ├── Update next-session.md with learnings                  │
│     ├── Git commit                                             │
│     └── Move to next task                                      │
│                                                                 │
│  7. Check context usage                                        │
│     └── If > 80% → invoke session-handoff, exit               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Task States

| Status | Meaning |
|--------|---------|
| `pending` | Not started |
| `in_progress` | Currently being worked on |
| `done` | Completed with evidence |
| `skipped` | Intentionally skipped (with reason) |
| `stuck` | Failed after max attempts |

### 1.3 Overnight Mode Specifics

When `--overnight` flag is set:

1. **No permission prompts**
   - All file edits auto-accepted
   - All bash commands auto-accepted

2. **Auto-restart on context limit**
   - At 80% context: complete current task, handoff
   - System will restart with `/auto-execute --continue`

3. **Extended iteration limit**
   - Max 500 iterations (vs 50 for interactive)

4. **Checkpoint after EVERY task**
   - Even small tasks get committed and state updated
   - Enables clean recovery if anything fails

### 1.4 Context Limit Handling

Monitor context usage throughout:

```
Context Usage Thresholds:
├── < 60%  → Continue normally
├── 60-80% → Warning, plan to finish current task
├── 80-95% → Complete current task, invoke session-handoff
└── > 95%  → Force checkpoint, immediate handoff
```

**At 80%+ usage:**

1. Complete current atomic change (don't leave half-done)
2. Run verification
3. Commit changes
4. Invoke session-handoff skill
5. Output handoff message
6. Exit cleanly

---

## PHASE 2: INTEGRATION

After all tasks complete (or all non-stuck tasks):

### 2.1 Pre-Integration Check

```bash
# Count completed vs stuck
DONE=$(jq '[.tasks[] | select(.status=="done")] | length' .claude/auto-execution/tasks.json)
STUCK=$(jq '[.tasks[] | select(.status=="stuck")] | length' .claude/auto-execution/tasks.json)
TOTAL=$(jq '.tasks | length' .claude/auto-execution/tasks.json)

echo "Completed: $DONE/$TOTAL"
echo "Stuck: $STUCK"
```

If any tasks stuck:
- In interactive mode: Ask user how to proceed
- In overnight mode: Continue with completed tasks, document stuck ones

### 2.2 Integration Steps

1. **Run full verification**
   ```bash
   npm test && npm run lint && npm run typecheck && npm run build
   ```

2. **If verification fails:**
   - Invoke systematic-debugging
   - Max 3 fix attempts
   - If still failing: mark integration as stuck

3. **If verification passes:**
   - Update state.yaml: status = "verification_passed"
   - Prepare for review

---

## PHASE 3: REVIEW & COMPLETION

**MANDATORY: Invoke `superpowers:verification-before-completion` skill**

### 3.1 Final Verification (Evidence Required)

Run FRESH verification (not cached):

```bash
# Must run each command and capture output
npm test 2>&1 | tee /tmp/test-output.txt
npm run lint 2>&1 | tee /tmp/lint-output.txt
npm run build 2>&1 | tee /tmp/build-output.txt
```

### 3.1.1 AI Code Quality Analysis

**Invoke ai-code-quality skill**

Semantic analysis of changed code:
- Complexity score (1-10)
- Maintainability index (1-10)
- Architecture compliance (1-10)
- Duplication score (1-10)
- Overall health score (1-10)

**Blocking Criteria:**
- Overall health < 5 → BLOCK
- Any dimension < 4 → BLOCK
- Critical architecture violations → BLOCK

### 3.1.2 Domain-Specific Verification

Read `.claude/auto-context.yaml` for work type:

**If work_type == FRONTEND:**
```
Invoke: webapp-testing skill (if available)
Invoke: e2e-validator skill (accessibility testing)
```
- Run Playwright e2e tests
- Take screenshots of UI
- Verify user interactions work
- Run accessibility audit (WCAG 2.1 AA)

**If database detected:**
```
Run schema-validator agent
```
- Verify DB schema matches code types

### 3.1.2 Code Review

**MANDATORY in Interactive mode, recommended in Overnight:**

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

### 3.2 Interactive vs Overnight Completion

**Interactive Mode:**
- Present results to user
- Ask for approval
- Wait for confirmation before completing

**Overnight Mode:**
- Create completion report at `.claude/auto-execution/completion-report.md`
- Commit all changes
- Update state.yaml: status = "completed"
- Output completion signal

### 3.3 Completion Report

```markdown
# Execution Complete

## Summary
- Feature: {name}
- Started: {timestamp}
- Completed: {timestamp}
- Tasks: {done}/{total} complete
- Sessions: {count}

## Changes Made
{list of files created/modified}

## Verification Results
```
{actual command outputs}
```

## Stuck Tasks (if any)
{list with reasons}

## Git Commits
{list of commits made}

## Next Steps
- Review branch: {branch name}
- Create PR if satisfied
- Or request adjustments
```

### 3.4 Completion Signal

**Interactive:**
```
Output: <promise>AUTO_COMPLETE</promise>
```
Only after user approval.

**Overnight:**
```
Output: <promise>OVERNIGHT_COMPLETE</promise>
```
After completion report written.

---

## STATE FILE UPDATES

### After Each Task

**tasks.json:**
```json
{
  "id": "task-N",
  "status": "done",
  "completed_at": "ISO timestamp",
  "evidence": "actual verification output"
}
```

**progress.md:**
```markdown
- [x] task-N: {name} [VERIFIED: {evidence}]
```

**next-session.md:**
```markdown
## Files Modified This Session
- {new file}

## Gotchas / Learnings
- {new learning}
```

**state.yaml:**
```yaml
current_task: "task-N+1"
session_history:
  - tasks_completed: ["task-N"]
```

### After Handoff

**state.yaml:**
```yaml
status: in_progress
session_history:
  - session_id: "..."
    ended_at: "..."
    reason: "context_limit"
    last_task_completed: "task-N"
```

---

## ERROR HANDLING

### Task Failure (After 3 Attempts)

```json
{
  "status": "stuck",
  "stuck_reason": "Test failure: expected X, got Y",
  "stuck_at": "ISO timestamp"
}
```

Create `.claude/auto-execution/stuck-report-task-N.md` with:
- Error details
- Investigation done
- Recommended fix

### Integration Failure

Update state.yaml:
```yaml
status: stuck
stuck_phase: integration
stuck_reason: "Build failure"
```

### Critical Error

1. Commit any salvageable work
2. Write detailed error to stuck-report.md
3. Update state to stuck
4. In overnight: continue with next task if possible
5. In interactive: ask user for guidance

---

## RESUME PROTOCOL (--continue)

When `--continue` flag is used:

1. **Read session_history from state.yaml**
   - Find last session entry
   - Check reason for ending

2. **Handle different end reasons:**

   | Reason | Action |
   |--------|--------|
   | `task_completed` | Start next pending task |
   | `context_limit` | Resume from current_task |
   | `error` | Check if error resolved, retry or skip |
   | `user_interrupt` | Start from current_task |

3. **Check for uncommitted changes:**
   ```bash
   git status --porcelain
   ```
   If changes exist:
   - In overnight: rollback and restart task
   - In interactive: ask user what to do

4. **Continue execution loop from Step 1**

---

## COMPLETION CRITERIA

Only output completion promise when ALL true:

- [ ] All tasks: status is "done" or "skipped" (not "pending" or "in_progress")
- [ ] Verification: tests, lint, typecheck, build all pass
- [ ] State: state.yaml status = "completed"
- [ ] Evidence: All claims have actual command output
- [ ] Interactive only: User has approved

---

## INTEGRATION WITH SKILLS

This command uses these skills:

| Phase | Skill | Purpose |
|-------|-------|---------|
| Bootstrap | execution-bootstrap | Read state, establish context |
| Execution | superpowers:test-driven-development | TDD discipline (RED→GREEN→REFACTOR) |
| Execution | superpowers:systematic-debugging | Fix failures (4-phase protocol) |
| Execution | rollback-manager | Auto-rollback on verify fail |
| Handoff | session-handoff | Prepare for next session |
| Review | superpowers:verification-before-completion | Evidence-based completion |
| Review | superpowers:requesting-code-review | Catch issues before done |
| Review | superpowers:receiving-code-review | Handle feedback properly |
| Review | ai-code-quality | Semantic code quality analysis |
| Review (FRONTEND) | webapp-testing | E2E tests, screenshots |
| Review (FRONTEND) | e2e-validator (a11y) | Accessibility testing |
| Review (DB) | schema-validator agent | Verify types match schema |

---

## BACKWARDS COMPATIBILITY

If no `.claude/auto-execution/` exists but plan file does:

1. Create minimal state files from plan
2. Execute as before
3. Recommend using `/auto-prepare` next time

```
Note: For optimal experience, use /auto-prepare first.
This enables:
- Fast context bootstrap
- Reliable session resume
- Clear state tracking

Continuing with legacy mode...
```
