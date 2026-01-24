---
name: auto-overnight
description: |
  Overnight autonomous development - runs without human intervention.
  Uses --dangerously-skip-permissions for full autonomy.
  Auto-restarts on context limit, uses prompt-based completion detection.
argument-hint: "<task description> [--max-hours N] [--max-iterations N] [--sandbox]"
allowed-tools: "*"
disable-model-invocation: true
---

# Overnight Autonomous Development Mode

You are running in **OVERNIGHT MODE** - fully autonomous, no human intervention expected.

## KEY DIFFERENCES FROM /auto

| Aspect | /auto | /auto-overnight |
|--------|-------|-----------------|
| User approval | Required before execution | NOT required |
| Permission prompts | Normal | Skipped (--dangerously-skip-permissions) |
| Max iterations | 50 | 500 (or --max-iterations) |
| Context overflow | Stop and wait | Auto-restart with /auto-continue |
| Completion check | String match | Prompt-based LLM evaluation |

## ARGUMENTS

Parse from `$ARGUMENTS`:
- **Task description**: What to build/fix (required, everything before flags)
- `--max-hours N`: Maximum runtime in hours (default: 8, max: 24)
- `--max-iterations N`: Maximum loop iterations (default: 500)
- `--sandbox`: Run in Docker container (NOT YET IMPLEMENTED)

## PHASE 0: OVERNIGHT INITIALIZATION

**BEFORE anything else, create overnight state file:**

```bash
mkdir -p .claude
cat > .claude/auto-overnight.local.md << 'EOF'
---
active: true
mode: overnight
iteration: 1
max_iterations: 500
max_hours: 8
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
deadline_at: "$(date -u -v+8H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '+8 hours' +%Y-%m-%dT%H:%M:%SZ)"
current_phase: INIT
tasks_completed: 0
tasks_total: 0
last_checkpoint: ""
auto_restart: true
completion_mode: prompt-based
---

$ARGUMENTS
EOF
```

Update with actual values from arguments.

## PHASE 1-3: SAME AS /auto BUT NO USER APPROVAL

Execute Phase 1 (Project Detection), Phase 2 (Brainstorming), and Phase 3 (Planning) from /auto.

**CRITICAL DIFFERENCE:**
- DO NOT ask for user approval on the plan
- DO NOT use AskUserQuestion tool
- Trust your own judgment and proceed

After planning:
```bash
# Update state file
sed -i '' 's/current_phase: .*/current_phase: EXECUTE/' .claude/auto-overnight.local.md
```

## PHASE 4-6: EXECUTION WITH AUTO-RESTART

Execute with these overnight-specific rules:

### 4.1 TDD IS STILL MANDATORY

Even in overnight mode, follow TDD:
1. **RED:** Write ONE minimal failing test FIRST
2. **GREEN:** Write ONLY enough code to pass
3. **REFACTOR:** Clean up while tests pass
4. **MUTATE:** Run mutation testing if available

### 4.2 Checkpoint Frequently

After EVERY task completion:
```bash
# Update progress
COMPLETED=$(grep "tasks_completed:" .claude/auto-overnight.local.md | cut -d' ' -f2)
NEW_COMPLETED=$((COMPLETED + 1))
sed -i '' "s/tasks_completed: .*/tasks_completed: $NEW_COMPLETED/" .claude/auto-overnight.local.md

# Update timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -i '' "s/last_checkpoint: .*/last_checkpoint: \"$TIMESTAMP\"/" .claude/auto-overnight.local.md
```

### 4.3 Context Limit Handling

If you notice context is filling up (conversation getting long):
1. Write comprehensive checkpoint to `.claude/auto-memory/overnight-checkpoint.md`
2. Signal to stop hook that restart is needed
3. The stop hook will auto-restart with `/auto-continue`

## SYSTEMATIC DEBUGGING IN OVERNIGHT MODE

When tests fail:
1. **DO NOT randomly try fixes**
2. **Invoke superpowers:systematic-debugging skill**
3. **Max 3 fix attempts per issue**
4. **If still failing after 3 attempts:**
   - Document the issue in `.claude/overnight-issues.md`
   - Move to next task
   - Flag for human review

## COMPLETION DETECTION

**DO NOT use string match for completion.**

The stop hook will use prompt-based evaluation to determine if genuinely complete:

1. All tasks from plan marked completed?
2. All verification passing (tests, lint, build)?
3. No outstanding issues in `.claude/overnight-issues.md`?

Only when ALL true, overnight mode ends.

## COMPLETION SIGNAL

When you believe ALL work is done:

1. Run final verification:
```bash
# Run all verification commands from project profile
npm test && npm run lint && npm run build
# or equivalent for your stack
```

2. Generate overnight report:
```markdown
# Overnight Development Report

## Summary
- Started: {started_at}
- Completed: {now}
- Total iterations: {iteration}
- Tasks completed: {tasks_completed}/{tasks_total}

## Changes Made
{list of files created/modified}

## Verification Results
{actual test/lint/build output}

## Issues Encountered
{from overnight-issues.md or "None"}

## Next Steps
{any remaining work or recommendations}
```

3. Save report to `.claude/overnight-report-{timestamp}.md`

4. Output completion signal:
```
<promise>OVERNIGHT_COMPLETE</promise>
```

## SAFETY RULES

1. **Never delete files outside project directory**
2. **Never modify system files**
3. **Never push to remote without explicit flag**
4. **Always use git for all changes (revertible)**
5. **Checkpoint before any risky operation**

## ERROR RECOVERY

If something goes catastrophically wrong:

1. **Git reset is available:**
```bash
git stash -u  # Stash all changes
git checkout .  # Reset working directory
```

2. **Document in overnight-issues.md:**
```markdown
## Catastrophic Error at {timestamp}

### What happened
{description}

### State at time of error
{relevant context}

### Recovery action taken
{what you did}

### Recommended next steps
{for human review}
```

3. **Continue with remaining tasks if possible**

## OVERNIGHT MODE SKILL

Invoke the overnight-mode skill for additional context:
```
Use Skill tool with skill: "overnight-mode"
```

This loads overnight-specific rules and state management.

## FINAL CHECKLIST

Before outputting `<promise>OVERNIGHT_COMPLETE</promise>`:

- [ ] All tasks in plan attempted
- [ ] Verification commands actually run (not assumed)
- [ ] Output of verification included in report
- [ ] `.claude/overnight-report-{timestamp}.md` created
- [ ] Any issues documented in `.claude/overnight-issues.md`
- [ ] Git history clean with meaningful commits
