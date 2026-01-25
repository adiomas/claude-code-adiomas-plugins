---
name: session-handoff
description: >
  This skill should be invoked at the END of any /auto-execute session,
  whether completing normally, hitting context limits, or encountering errors.
  Properly saves state for the next session to continue seamlessly.
---

# Session Handoff Skill

Properly end an execution session and prepare handoff to the next session.
This skill ensures continuity across session boundaries.

## When This Skill Activates

- Task completed, preparing for next task
- Context limit approaching (~80% used)
- Session ending (user interrupt, error, completion)
- Before any `<promise>` completion signal

## Core Principle

**Leave clear breadcrumbs for the next session.**

From Anthropic's research:
> "The coding agent makes incremental progress in every session,
> while leaving clear artifacts for the next session."

## Handoff Protocol

### Step 1: Update tasks.json

After completing a task, update its status:

```json
{
  "id": "task-2",
  "status": "done",
  "completed_at": "2024-01-15T11:30:00Z",
  "evidence": "npm test -- auth.test.ts\n✓ 8 tests passed"
}
```

**CRITICAL:** Include actual verification output in `evidence` field.

### Step 2: Update progress.md

Human-readable progress update:

```markdown
## Progress: 2/5 tasks complete (40%)

### ✅ Completed
- [x] task-1: Create User model [VERIFIED: 4 tests passing]
- [x] task-2: Create auth middleware [VERIFIED: 8 tests passing]

### 🔄 Next Up
- [ ] task-3: Create login endpoint

### Verification History
| Timestamp | Tests | Lint | Build | Notes |
|-----------|-------|------|-------|-------|
| 10:30:00  | ✅ 4/4 | ✅ 0 | ✅ | task-1 |
| 11:30:00  | ✅ 12/12 | ✅ 0 | ✅ | task-2 |
```

### Step 3: Update state.yaml

Update machine-readable state:

```yaml
status: in_progress
current_task: task-3
current_group: 1
session_history:
  - session_id: "sess-20240115-103000"
    started_at: "2024-01-15T10:30:00Z"
    ended_at: "2024-01-15T11:45:00Z"
    reason: "task_completed"  # or context_limit, error, user_interrupt
    tasks_completed: ["task-1", "task-2"]
    last_task_completed: "task-2"
```

### Step 4: Update next-session.md (MOST IMPORTANT)

This file is the PRIMARY context for the next session:

```markdown
# Next Session Context

## Current State
- Last completed: task-2 (Create auth middleware)
- Next task: task-3 (Create login endpoint)
- Verification status: All tests passing (12/12)
- Progress: 40% (2/5 tasks)

## Key Decisions Made
- Using bcrypt for password hashing (not argon2) - user preference
- JWT tokens expire after 24h
- Refresh tokens stored in httpOnly cookies
- Auth middleware checks Bearer token in Authorization header

## Files Modified This Session
- src/middleware/auth.ts (created)
- src/middleware/auth.test.ts (created)
- src/models/user.ts (modified - added password methods)

## Gotchas / Learnings
- Project uses Vitest, not Jest
- Database is Supabase, use their client
- Token verification needs async/await (Supabase client is async)
- Remember to handle expired token case separately

## Next Steps
1. Create login endpoint at src/api/auth/login.ts
2. Accept email + password in request body
3. Verify password with bcrypt.compare()
4. Generate JWT token on success
5. Return token in response

## Code References
Key files for next task:
- src/middleware/auth.ts:42 - verifyToken function to reuse
- src/models/user.ts:28 - User.findByEmail() method
```

### Step 5: Git Commit

Create a commit with clear message:

```bash
git add -A
git commit -m "feat(task-2): Create auth middleware

- Added JWT verification middleware
- Added token generation utility
- All tests passing (8/8)

Progress: 2/5 tasks (40%)
Next: task-3 (Create login endpoint)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

**CRITICAL:** Include progress and next task in commit message.

## Context Limit Handling

When context usage reaches ~80%:

### Step 1: Complete Current Work

If mid-task:
1. Finish current atomic change
2. Run verification
3. Commit if passing
4. OR rollback if failing

### Step 2: Write Detailed Handoff

More detail than normal handoff:

```markdown
# Next Session Context

## ⚠️ SESSION ENDED: Context Limit

This session ended due to approaching context limit.
Current work was checkpointed safely.

## Current State
- Task in progress: task-3 (Create login endpoint)
- Task status: PARTIALLY COMPLETE
- Files created: src/api/auth/login.ts (incomplete)

## What Was Done
1. ✅ Created login route handler
2. ✅ Added request validation
3. ⏳ Password verification (in progress)
4. ❌ Token generation (not started)
5. ❌ Response handling (not started)

## What Remains
Continue from step 3:
- Complete password verification in login.ts:45
- Add token generation call
- Add success/failure responses

## Files to Review
- src/api/auth/login.ts - INCOMPLETE, review before continuing

## Important Context
- Was implementing async password check
- Using bcrypt.compare() - remember it's async
- Error handling pattern from auth.ts should be followed
```

### Step 3: Signal Handoff

Output clear handoff message:

```
═══════════════════════════════════════════════════════════════════
 ⚠️ SESSION CHECKPOINT - Context Limit Approaching
═══════════════════════════════════════════════════════════════════

 Progress: 2.5/5 tasks
 Last complete: task-2
 In progress: task-3 (partially complete)

 State saved to:
   • .claude/auto-execution/state.yaml
   • .claude/auto-execution/next-session.md

 To continue, start a new session and run:
   /auto-execute --continue

═══════════════════════════════════════════════════════════════════
```

## Completion Handoff

When all tasks are done:

### Step 1: Final Verification

```bash
# Run full verification suite
npm test
npm run lint
npm run typecheck
npm run build
```

### Step 2: Update State to Completed

```yaml
status: completed
current_task: null
completed_at: "2024-01-15T14:00:00Z"
```

### Step 3: Create Completion Report

Update next-session.md with completion summary:

```markdown
# Execution Complete

## Summary
- Feature: User Authentication
- Started: 2024-01-15T10:30:00Z
- Completed: 2024-01-15T14:00:00Z
- Tasks: 5/5 complete
- Sessions: 3

## Changes Made
| File | Change |
|------|--------|
| src/models/user.ts | Created User model |
| src/middleware/auth.ts | Created auth middleware |
| src/api/auth/login.ts | Created login endpoint |
| src/api/auth/register.ts | Created register endpoint |
| src/api/auth/logout.ts | Created logout endpoint |

## Verification Results
```
npm test
✓ 24 tests passed

npm run lint
✓ No issues found

npm run build
✓ Build successful
```

## Next Steps
1. Review changes on branch: auto/user-auth-20240115
2. Create PR if satisfied
3. Or request adjustments
```

### Step 4: Signal Completion

```
═══════════════════════════════════════════════════════════════════
 ✅ EXECUTION COMPLETE
═══════════════════════════════════════════════════════════════════

 Feature: User Authentication
 Progress: 5/5 tasks (100%)
 Branch: auto/user-auth-20240115

 Verification:
   Tests: ✅ 24 passing
   Lint:  ✅ 0 errors
   Build: ✅ Success

 Changes ready for review.

 Options:
   A) Create PR: gh pr create --title "Add user authentication"
   B) Review changes: git diff main...HEAD
   C) Make adjustments: describe what to change

═══════════════════════════════════════════════════════════════════
```

## Error Handoff

When an error prevents continuation:

### Step 1: Document the Error

```markdown
# Next Session Context

## ❌ SESSION ENDED: Error Encountered

## Error Details
- Task: task-3 (Create login endpoint)
- Error type: Test failure
- Attempts: 3 (max reached)

## Error Output
```
npm test -- login.test.ts

FAIL src/api/auth/login.test.ts
  ● login › should return 401 for invalid password

    Expected: 401
    Received: 500

    at Object.<anonymous> (login.test.ts:45:12)
```

## Investigation Done
1. Checked password comparison - correct
2. Checked error handling - ISSUE FOUND
   - bcrypt.compare throws on invalid hash format
   - We're not catching this case

## Recommended Fix
Add try-catch around bcrypt.compare in login.ts:52

## Files Involved
- src/api/auth/login.ts:52 - add error handling
- src/api/auth/login.test.ts:45 - failing test
```

### Step 2: Update State

```yaml
status: stuck
current_task: task-3
stuck_reason: "Test failure after 3 fix attempts"
stuck_report: ".claude/auto-execution/stuck-report.md"
```

### Step 3: Signal Need for Help

```
═══════════════════════════════════════════════════════════════════
 ⛔ EXECUTION STUCK - Manual Intervention Needed
═══════════════════════════════════════════════════════════════════

 Task: task-3 (Create login endpoint)
 Issue: Test failure after 3 attempts

 Details: .claude/auto-execution/stuck-report.md

 Options:
   1. Review stuck-report.md and provide guidance
   2. Fix manually and run /auto-execute --continue
   3. Skip this task: update tasks.json status to "skipped"

═══════════════════════════════════════════════════════════════════
```

## Handoff Checklist

Before ending ANY session:

- [ ] tasks.json updated with task status
- [ ] progress.md updated with human-readable progress
- [ ] state.yaml updated with session history
- [ ] next-session.md updated with context for next session
- [ ] Git commit created with progress in message
- [ ] Clear handoff message displayed

## Best Practices

1. **Update state incrementally** - After each task, not just at session end
2. **Be specific in next-session.md** - Line numbers, function names, decisions
3. **Include evidence** - Actual test output, not "tests pass"
4. **Git commit often** - Each task = one commit
5. **Clear handoff messages** - Tell user exactly what to do next
