---
name: auto-lite
description: |
  DEPRECATED: Use /do instead. This command will be removed in v5.0.
  Lightweight autonomous development for simple tasks.
  Skips brainstorming and planning phases - goes straight to execution.
  Use for typo fixes, simple refactors, or well-defined small changes.
argument-hint: "<simple task description>"
allowed-tools: ["Task", "Bash", "Read", "Write", "Edit", "Glob", "Grep", "TodoWrite"]
---

# DEPRECATED - Use /do Instead

> **This command is deprecated.** Use `/do <task>` for the new AGI-like interface.
>
> The new `/do` command automatically detects simple tasks and uses DIRECT mode.
> No need for a separate "lite" command - `/do` adapts to complexity.
>
> Migration: Simply replace `/auto-lite <task>` with `/do <task>`
> See: `autonomous-dev/docs/migration-v4.md` for details.

---

# Autonomous Development - Lite Mode (Legacy)

A streamlined version of `/auto` for simple, well-defined tasks.

**Use when:**
- Task is small and well-defined
- No design decisions needed
- Single file or few files
- Typo fixes, simple refactors, obvious bug fixes

**Don't use when:**
- Task requires design discussion
- Multiple approaches possible
- Significant new functionality
- User requirements are unclear

## Lite Mode Flow

```
Full /auto:    1. Detect → 2. Brainstorm → 3. Plan → 4. Execute → 4.5. Validate → 5. Integrate → 6. Review
Lite /auto-lite: 1. Detect ─────────────────────────→ 4. Execute ─────────────────────────────→ 6. Review
```

## PHASE 1: Quick Detection

### 1.1 Project Profile
Check if `.claude/project-profile.yaml` exists:
- If exists: use it
- If not: run quick detection script

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/detect-project.sh
```

### 1.2 Skip Classification
Don't create `.claude/auto-context.yaml` - lite mode is context-free.

## PHASE 4: Direct Execution (Skip 2 & 3)

### 4.1 Understand Task
Parse the user's request directly. For lite mode, assume:
- User knows what they want
- Task is straightforward
- No design discussion needed

### 4.2 TDD Still Applies (If Applicable)

**For code changes:**
1. **RED:** Write minimal failing test (if test-worthy)
2. **GREEN:** Implement fix
3. **REFACTOR:** Clean up

**For non-testable changes (typos, docs):**
- Skip TDD, just make the change
- Verify with appropriate tool (spell check, build, etc.)

### 4.3 Execute in Main Branch

No worktrees for lite mode - work directly:
```bash
# Make changes
# Run verification
# Commit if successful
```

### 4.4 Verification

Run appropriate verification:
```bash
# Read commands from profile
TYPECHECK=$(yq -r '.commands.typecheck // ""' .claude/project-profile.yaml)
LINT=$(yq -r '.commands.lint // ""' .claude/project-profile.yaml)
TEST=$(yq -r '.commands.test // ""' .claude/project-profile.yaml)

# Run what's available
[[ -n "$TYPECHECK" ]] && $TYPECHECK
[[ -n "$LINT" ]] && $LINT
[[ -n "$TEST" ]] && $TEST
```

## PHASE 6: Quick Review

### 6.1 Show Changes
```bash
git diff --stat
git diff
```

### 6.2 Present to User
```markdown
## Changes Made

**Files modified:**
- [list files]

**Verification:**
- Typecheck: ✅ Pass
- Lint: ✅ Pass
- Test: ✅ Pass

**Ready to commit?** (y/n)
```

## Lite Mode Constraints

1. **No parallel execution** - Single-threaded only
2. **No worktrees** - Work directly on current branch
3. **No Phase 4.5** - Skip integration validation (single task)
4. **Minimal questions** - Assume user intent is clear
5. **Fast feedback** - Get it done quickly

## When to Escalate to Full /auto

If during lite execution you discover:
- Task is more complex than expected
- Multiple approaches possible
- Need user input on design decisions
- Will require multiple files with dependencies

**STOP and suggest:**
"This task seems more complex than lite mode handles. Would you like to run `/auto` instead for proper planning?"

## Example Usage

```
/auto-lite "fix typo in README.md - 'recieve' should be 'receive'"
/auto-lite "add type annotation to getUserById function"
/auto-lite "rename variable 'tmp' to 'temporaryValue' in utils.ts"
/auto-lite "remove unused import in Header.tsx"
```

## Completion

For lite mode, completion is simple:
1. Changes made
2. Verification passed
3. User confirmed

No elaborate completion promise needed - just confirm done.
