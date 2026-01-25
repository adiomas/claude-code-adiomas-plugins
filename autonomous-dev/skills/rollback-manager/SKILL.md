---
name: rollback-manager
description: >
  This skill handles automatic rollback when verification fails during autonomous execution.
  Provides safe recovery from failed tasks, partial rollbacks, and maintains rollback history.
  Invoked automatically when verification fails or when user requests "rollback", "undo changes",
  "revert task".
---

# Rollback Manager Skill

Automatic and safe rollback mechanism for failed autonomous execution.

## Why Auto-Rollback Matters

Without auto-rollback:
1. Verification fails
2. Code stays in broken state
3. Next task builds on broken code
4. Cascade of failures
5. Manual cleanup required

With auto-rollback:
1. Verification fails
2. **Automatic revert to last good state**
3. Task marked as "failed"
4. Next task can proceed (if independent)
5. Clean recovery

## Rollback Types

### 1. Task Rollback

Revert a single task's changes.

```bash
# Rollback task-3 only
git checkout HEAD~1 -- src/components/UserForm.tsx src/components/UserForm.test.tsx
```

**When used:**
- Single task verification fails
- Task is independent (no dependents affected)

### 2. Full Rollback

Revert all changes since last checkpoint.

```bash
# Return to checkpoint state
git reset --hard $(cat .claude/auto-execution/last-good-commit)
```

**When used:**
- Integration validation fails
- Multiple interdependent tasks fail
- Critical error detected

### 3. Partial Rollback

Revert specific files while keeping others.

```bash
# Keep passing files, revert failing ones
git checkout HEAD~1 -- src/api/broken.ts
git add src/api/working.ts
git commit --amend
```

**When used:**
- Some files pass verification, others don't
- Want to preserve working changes

## Rollback Protocol

### Step 1: Detect Failure

```yaml
# Trigger conditions
triggers:
  - verification_exit_code != 0
  - test_failure_count > 0
  - lint_error_count > 0
  - build_failure: true
  - ai_quality_score < threshold
```

### Step 2: Assess Impact

Before rolling back, analyze what's affected:

```markdown
## Rollback Impact Analysis

**Failed Task:** task-3 (Create UserForm)
**Files Changed:**
- src/components/UserForm.tsx (created)
- src/components/UserForm.test.tsx (created)
- src/types/user.ts (modified - added FormData type)

**Dependent Tasks:**
- task-4 (uses UserForm) - WILL BE AFFECTED
- task-5 (unrelated) - NOT AFFECTED

**Recommendation:** Task Rollback (revert task-3 only)
```

### Step 3: Execute Rollback

#### For Task Rollback:

```bash
#!/bin/bash
# rollback-task.sh

TASK_ID=$1
TASK_BRANCH="auto/${TASK_ID}"

# Get files changed by this task
FILES=$(git diff --name-only main...${TASK_BRANCH})

# Revert those files
git checkout main -- $FILES

# Update state
yq -i ".tasks[] | select(.id == \"${TASK_ID}\") | .status = \"rolled_back\"" \
  .claude/auto-execution/tasks.json

# Log rollback
echo "$(date -Iseconds) | ROLLBACK | ${TASK_ID} | Verification failed" >> \
  .claude/auto-execution/rollback-history.log
```

#### For Full Rollback:

```bash
#!/bin/bash
# rollback-full.sh

# Get last good commit
LAST_GOOD=$(cat .claude/auto-execution/last-good-commit)

# Hard reset
git reset --hard $LAST_GOOD

# Update all in-progress tasks to rolled_back
jq '.tasks[] | select(.status == "in_progress") | .status = "rolled_back"' \
  .claude/auto-execution/tasks.json > tmp.json && mv tmp.json .claude/auto-execution/tasks.json

# Log rollback
echo "$(date -Iseconds) | FULL_ROLLBACK | ALL | Critical failure" >> \
  .claude/auto-execution/rollback-history.log
```

### Step 4: Update State

After rollback, update execution state:

```yaml
# .claude/auto-execution/state.yaml
status: rollback_complete
last_rollback:
  timestamp: "2024-01-15T14:30:00Z"
  type: task  # task | full | partial
  task_id: task-3
  reason: "Test failure: expected 200, got 500"
  files_reverted:
    - src/components/UserForm.tsx
    - src/components/UserForm.test.tsx
  recovery_action: retry  # retry | skip | manual
```

### Step 5: Recovery Decision

After rollback, decide next action:

```
┌─────────────────────────────────────────────────────────────────┐
│ ROLLBACK COMPLETE                                               │
│                                                                 │
│ Task: task-3 (Create UserForm)                                  │
│ Reason: Test failure                                            │
│ Files reverted: 2                                               │
│                                                                 │
│ Recovery Options:                                               │
│                                                                 │
│   [R] Retry task with different approach                        │
│   [S] Skip task and continue                                    │
│   [M] Manual intervention required                              │
│   [A] Abort execution                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Automatic mode (overnight):**
- Attempt 1-2: Retry with pivot
- Attempt 3: Skip and continue
- Critical failure: Abort with report

**Interactive mode:**
- Ask user for decision

## Rollback History

Maintain history for debugging:

```
# .claude/auto-execution/rollback-history.log

2024-01-15T14:30:00Z | TASK_ROLLBACK | task-3 | Test failure: expected 200, got 500
2024-01-15T14:45:00Z | TASK_ROLLBACK | task-3 | Retry 1: Same failure
2024-01-15T15:00:00Z | SKIP | task-3 | Max retries reached, skipping
2024-01-15T16:30:00Z | FULL_ROLLBACK | ALL | Integration validation failed
```

## Checkpoint Management

### Save Checkpoint (Before Risky Operations)

```bash
# Save current good state
git rev-parse HEAD > .claude/auto-execution/last-good-commit
cp .claude/auto-execution/tasks.json .claude/auto-execution/tasks.json.backup
cp .claude/auto-execution/state.yaml .claude/auto-execution/state.yaml.backup

echo "Checkpoint saved: $(cat .claude/auto-execution/last-good-commit)"
```

### Checkpoint Triggers

Save checkpoint automatically when:
- Task completes successfully
- Verification passes
- Before integration phase
- Every N minutes (configurable)

```yaml
# .claude/auto-config.yaml
rollback:
  checkpoint_on_task_complete: true
  checkpoint_on_verify_pass: true
  checkpoint_interval_minutes: 15
  max_checkpoints: 10  # Keep last 10
```

## Integration with auto-execute

Add to execution loop in `/auto-execute`:

```markdown
### 1.5 Verification with Auto-Rollback

After each task verification:

1. Run verification command
2. Check exit code

IF exit_code != 0:
   a. Invoke rollback-manager skill
   b. Assess impact
   c. Execute appropriate rollback
   d. Update state
   e. Decide recovery action:
      - Overnight: auto-retry or skip
      - Interactive: ask user

IF exit_code == 0:
   a. Save checkpoint
   b. Update last-good-commit
   c. Continue to next task
```

## Rollback Report

Generate after any rollback:

```markdown
# Rollback Report

## Event
- **Timestamp:** 2024-01-15T14:30:00Z
- **Type:** Task Rollback
- **Task:** task-3 (Create UserForm component)

## Failure Details
```
npm test -- UserForm.test.tsx

FAIL src/components/UserForm.test.tsx
  ● UserForm › submits form data correctly

    Expected: POST /api/users with { name: "John" }
    Received: POST /api/users with { name: undefined }

    at Object.<anonymous> (UserForm.test.tsx:45:12)
```

## Root Cause Analysis
The form submission doesn't extract `name` from form data correctly.
Line 23 in UserForm.tsx: `name: formData.name` should be `name: formData.get('name')`

## Files Reverted
- src/components/UserForm.tsx
- src/components/UserForm.test.tsx

## Recovery Action
**Retry** - Will attempt with corrected approach

## Lessons Learned
- Form data extraction differs between FormData and plain object
- Add type checking for form data access patterns
```

## Safety Mechanisms

### 1. Never Lose Work

Before any rollback:
```bash
# Create backup branch
git branch backup/pre-rollback-$(date +%Y%m%d-%H%M%S)
```

### 2. Confirm Destructive Actions

In interactive mode, always confirm:
```
⚠️  This will revert 5 files. Changes will be saved to backup branch.
    Continue? [y/N]
```

### 3. Preserve Evidence

Before reverting, save failure evidence:
```bash
# Save test output
npm test 2>&1 > .claude/auto-execution/failures/task-3-test-output.txt

# Save current state
git diff > .claude/auto-execution/failures/task-3-diff.patch
```

## Configuration

```yaml
# .claude/auto-config.yaml
rollback:
  enabled: true
  auto_rollback_on_verify_fail: true
  max_retry_attempts: 3
  create_backup_branch: true
  preserve_failure_evidence: true

  # Thresholds for auto-decisions
  auto_retry_if:
    - test_failure_count <= 3
    - error_type: "assertion"

  auto_skip_if:
    - retry_count >= 3
    - error_type: "configuration"

  abort_if:
    - critical_file_corrupted: true
    - git_state_invalid: true
```

## When NOT to Use This Skill

Do NOT auto-rollback when:

1. **User explicitly disabled** - `rollback.enabled: false`
2. **Manual debugging in progress** - User is investigating
3. **Partial success is acceptable** - Some failures are OK
4. **Non-code changes** - Config changes might need manual review
5. **Already in rollback state** - Prevent rollback loops
