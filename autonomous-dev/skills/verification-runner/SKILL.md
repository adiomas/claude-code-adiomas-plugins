---
name: verification-runner
description: >
  This skill should be used when the user asks to "run verification",
  "check if code passes", "run tests and lint", "verify implementation",
  or after code changes in autonomous mode.
  Runs typecheck, lint, test, and build in optimal order for fast feedback.
---

# Verification Runner Skill

Execute the project verification pipeline in optimal order to catch errors early.

## Verification Order

Run checks in this sequence for fastest feedback:

| Order | Check | Rationale |
|-------|-------|-----------|
| 1 | Typecheck | Fastest, catches most errors |
| 2 | Lint | Fast, catches style issues |
| 3 | Test | Slower, catches logic errors |
| 4 | Build | Slowest, catches bundling issues |

## Protocol

### Step 1: Load Project Profile

Read `.claude/project-profile.yaml` to get verification commands:
```yaml
commands:
  typecheck: "npm run typecheck"
  lint: "npm run lint"
  test: "npm test"
  build: "npm run build"
verification:
  required: ["test", "lint", "typecheck"]
  optional: ["build"]
```

### Step 2: Determine What to Run

Execute verifications based on configuration:
- **Required** - Must pass before marking complete
- **Optional** - Run but don't block on failure

### Step 3: Execute in Order

Run each verification command, stopping on first failure for required checks.

### Step 4: Handle Failures

For each failure type:

| Failure | Action |
|---------|--------|
| Typecheck | Fix type errors, retry |
| Lint | Auto-fix if possible, otherwise fix manually, retry |
| Test | Analyze failure, fix logic, retry |
| Build | Analyze error, fix configuration, retry |

### Step 5: Report Results

Present verification summary:
```
Verification Results:
  Typecheck: passed
  Lint: passed (2 auto-fixed)
  Tests: 42 passed, 0 failed
  Build: success
```

## Smart Test Optimization

For Jest/Vitest projects with `--changedSince` support:

1. Run tests only for changed files first:
   ```bash
   npm test -- --changedSince=HEAD~1
   ```

2. If changed tests pass, run full suite
3. This saves significant time on large test suites

## Additional Resources

### Reference Files

For detailed verification commands:
- **`references/verification-commands.md`** - Complete commands for JS/TS, Python, Go, Rust projects

## Script Reference

Execute verification directly:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/run-verification.sh [mode]
```

Modes:
- `all` - Run all verifications
- `required` - Run only required verifications
- `test` / `lint` / etc. - Run specific verification
