---
name: auto-smart
description: |
  DEPRECATED: Use /do instead. This command will be removed in v5.0.
  Intelligent autonomous development - the best of Ralph Wiggum and autonomous-dev combined.
  Analyzes complexity, chooses optimal mode (DIRECT vs ORCHESTRATED), executes fully autonomously.
  NO approval gates - fire and forget with intelligent recovery.
argument-hint: "<task description>"
allowed-tools: ["Task", "Bash", "Read", "Write", "Edit", "Glob", "Grep", "TodoWrite", "Skill"]
---

# DEPRECATED - Use /do Instead

> **This command is deprecated.** Use `/do <task>` for the new AGI-like interface.
>
> The new `/do` command includes all features of `/auto-smart`:
> - Automatic complexity scoring
> - DIRECT vs ORCHESTRATED mode selection
> - Fire and forget execution
> - Intelligent recovery
>
> Migration: Simply replace `/auto-smart <task>` with `/do <task>`
> See: `autonomous-dev/docs/migration-v4.md` for details.

---

# Smart Ralph - Intelligent Autonomous Development (Legacy)

Combines Ralph Wiggum's simplicity with autonomous-dev's intelligence. Fully autonomous execution without approval gates.

## When to Use

**Perfect for:**
- Any task you want done autonomously (simple OR complex)
- Overnight/unattended execution
- Tasks where you trust Claude's judgment
- "Fire and forget" scenarios

**The key difference from `/auto`:** NO approval gates. It runs to completion or checkpoints if stuck.

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  PHASE 1: SMART_ANALYZE (~30 seconds)                       │
│  ├── Detect project (reuse project-detector)                │
│  ├── Score complexity (1-5)                                 │
│  ├── Choose mode: DIRECT (1-2) or ORCHESTRATED (3-5)        │
│  └── Output analysis summary                                │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  PHASE 2: EXECUTE (mode-dependent)                          │
│  ┌─────────────────────────┐ ┌────────────────────────────┐ │
│  │ DIRECT (simple tasks)   │ │ ORCHESTRATED (complex)     │ │
│  │ • Loop until done       │ │ • Auto-decompose 2-5 phases│ │
│  │ • Evidence gates        │ │ • Checkpoint per phase     │ │
│  │ • Self-verify           │ │ • Evidence gates per phase │ │
│  └─────────────────────────┘ └────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  PHASE 3: SMART_VERIFY                                      │
│  ├── Collect all evidence                                   │
│  ├── Final verification (test, build, lint, typecheck)      │
│  └── Output COMPLETE with summary                           │
└─────────────────────────────────────────────────────────────┘
```

## PHASE 1: SMART_ANALYZE

### 1.1 Project Detection

Use existing project-detector:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/detect-project.sh
```

### 1.2 Complexity Analysis

Invoke the smart-mode skill for complexity scoring:

```
Score 1: Single file, <50 LOC, trivial fix     → DIRECT
Score 2: 2-3 files, <200 LOC, single feature   → DIRECT
Score 3: 4-7 files, multi-component            → ORCHESTRATED
Score 4: 8-15 files, architecture changes      → ORCHESTRATED
Score 5: 15+ files, full application           → ORCHESTRATED
```

**Heuristic Signals:**
- Keywords "full", "complete", "entire", "system" → +1
- Keywords "simple", "quick", "just", "only" → -1
- Multiple features mentioned → +1 per feature
- Database/auth/payment mentioned → +1

### 1.3 Initialize State

Create `.claude/smart-ralph/state.yaml`:
```yaml
version: "1.0"
mode: DIRECT|ORCHESTRATED
phase: ANALYZE
complexity:
  score: 3
  reasoning: "Multiple components detected"
  mode_selected: ORCHESTRATED
started_at: "2024-01-15T10:30:00Z"
prompt: "<original user prompt>"
failure_recovery:
  pivot_count: 0
  research_count: 0
  last_error: null
```

### 1.4 Output Analysis

Display to user:
```
┌─────────────────────────────────────────┐
│  SMART RALPH - Analysis Complete        │
├─────────────────────────────────────────┤
│  Project: Next.js + TypeScript          │
│  Complexity: 3/5                        │
│  Mode: ORCHESTRATED                     │
│  Phases: 3 (auto-determined)            │
│                                         │
│  Starting execution...                  │
└─────────────────────────────────────────┘
```

## PHASE 2: EXECUTE

### 2.1 DIRECT Mode (Complexity 1-2)

Simple iterative execution:

1. **Understand** - Parse task requirements
2. **Implement** - Make changes with TDD when applicable
3. **Verify** - Run verification after each change
4. **Evidence Gate** - Document verification results
5. **Loop** - Continue until complete

**Evidence Gate Format (MANDATORY):**
```
✅ "Implemented login form [VERIFIED: npm test login.test.ts → 5 passing]"
❌ "Implemented login form" (no evidence = INVALID)
```

### 2.2 ORCHESTRATED Mode (Complexity 3-5)

Phased execution with checkpoints:

1. **Decompose** - Break into 2-5 logical phases (NOT individual tasks)
2. **Execute Phase** - Complete one phase at a time
3. **Checkpoint** - Save state after each phase
4. **Evidence Gate** - Verify phase completion
5. **Continue** - Move to next phase

**Phase Structure:**
```yaml
orchestrated_phases:
  - id: 1
    name: "Setup infrastructure"
    status: pending|in_progress|complete
    evidence: []
  - id: 2
    name: "Implement core feature"
    status: pending
    evidence: []
```

### 2.3 Failure Handling (CRITICAL)

**Stuck Detection:**
- Same error 3 consecutive times
- No file changes in 5 iterations
- Explicit "I don't know how" statement

**Recovery Protocol:**

```
LEVEL 1: PIVOT (first 3 attempts)
├── Identify what failed and why
├── List 2-3 alternative approaches
├── Choose most promising
└── Attempt with fresh perspective

LEVEL 2: RESEARCH (after 3 failed pivots)
├── Read more related code in codebase
├── Search for similar patterns
├── Understand dependencies better
└── Reformulate approach with new knowledge

LEVEL 3: CHECKPOINT (after 3 failed research cycles)
├── Save complete state to .claude/smart-ralph/
├── Write detailed stuck-report.md
├── Output: "STUCK - manual intervention needed"
└── Exit gracefully with full context preserved
```

**Max Cycles:** 10 total (pivot + research) before hard stop.

## PHASE 3: SMART_VERIFY

### 3.1 Collect Evidence

All verification must be documented:
```markdown
## Evidence Collected
- [x] `npm test` → 24 passing, 0 failing
- [x] `npm run build` → success (0 errors)
- [x] `npm run lint` → 0 errors, 0 warnings
- [x] `tsc --noEmit` → no errors
```

### 3.2 Final Verification

Run complete verification pipeline:
```bash
# Read commands from profile
TYPECHECK=$(yq -r '.commands.typecheck // ""' .claude/project-profile.yaml)
LINT=$(yq -r '.commands.lint // ""' .claude/project-profile.yaml)
TEST=$(yq -r '.commands.test // ""' .claude/project-profile.yaml)
BUILD=$(yq -r '.commands.build // ""' .claude/project-profile.yaml)

# Run in order (fastest to slowest for early failure)
[[ -n "$TYPECHECK" ]] && $TYPECHECK
[[ -n "$LINT" ]] && $LINT
[[ -n "$TEST" ]] && $TEST
[[ -n "$BUILD" ]] && $BUILD
```

### 3.3 COMPLETE Signal

**CANNOT output COMPLETE without ALL verifications passing:**

```markdown
## COMPLETE

### Summary
- **Mode:** ORCHESTRATED (Complexity 3/5)
- **Phases completed:** 3/3
- **Duration:** ~15 minutes

### What was built
1. Authentication system with login/register
2. Password reset flow with email
3. Session management with JWT

### Verification
- [x] All tests passing (24/24)
- [x] Build successful
- [x] Lint clean
- [x] Type check passed

### Files changed
- src/auth/login.ts (new)
- src/auth/register.ts (new)
- src/auth/reset-password.ts (new)
- src/middleware/auth.ts (modified)
```

## Memory & Resume

### State Persistence

All state saved to `.claude/smart-ralph/`:
- `state.yaml` - Current execution state
- `progress.md` - Human-readable progress
- `stuck-report.md` - Only if stuck (detailed context for resume)

### Auto-Resume

On next session, if incomplete state detected:
```
┌─────────────────────────────────────────┐
│  SMART RALPH - Incomplete Session Found │
├─────────────────────────────────────────┤
│  Previous task: "Build auth system"     │
│  Progress: Phase 2/3 complete           │
│  Last activity: 2 hours ago             │
│                                         │
│  Resuming from Phase 3...               │
└─────────────────────────────────────────┘
```

## Evidence Protocol (NON-NEGOTIABLE)

Every claim MUST have verification:

**Allowed:**
```
Implemented user registration [VERIFIED: npm test auth/register.test.ts → 8 passing]
Fixed the login bug [VERIFIED: npm test → all 24 tests passing]
Added password validation [VERIFIED: manual test - rejects weak passwords]
```

**NOT Allowed:**
```
I've implemented the feature (no evidence)
The login should work now (speculation)
I think the tests pass (not verified)
```

**Red Flag Words (trigger re-verification):**
- "should"
- "probably"
- "I think"
- "seems to"
- "likely"

## Comparison with Other Modes

| Aspect | /auto | /auto-lite | /auto-smart |
|--------|-------|------------|-------------|
| Planning | Full brainstorm | Skip | Adaptive (if needed) |
| Approval gates | Yes (Phase 3, 6) | No | **No** |
| Complexity handling | Always full | Assumes simple | **Auto-detects** |
| Failure recovery | Manual | Escalate | **Auto pivot/research** |
| Multi-session | Checkpoint | No | **Auto-resume** |
| Parallelization | Yes | No | **If ORCHESTRATED** |
| Best for | Quality | Speed | **Autonomy** |

## Example Usage

```bash
# Simple task - will use DIRECT mode
/auto-smart "fix the typo in README.md"

# Medium task - will use DIRECT mode
/auto-smart "add a logout button to the header"

# Complex task - will use ORCHESTRATED mode
/auto-smart "build complete authentication with login, register, and password reset"

# Very complex - will use ORCHESTRATED with multiple phases
/auto-smart "create a full dashboard with user management, analytics, and settings"
```

## When Smart Ralph Stops

1. **COMPLETE** - All done, verified, evidence collected
2. **STUCK** - Max recovery attempts exhausted, checkpoint saved
3. **SESSION_END** - Token limit approaching, checkpoint saved for resume

In all cases, state is preserved and resumable.
