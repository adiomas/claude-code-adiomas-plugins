# Direct Executor

Executes simple tasks (complexity 1-2) without phases or checkpoints.

## When to Use

- Complexity 1-2 tasks
- Single-file changes
- Quick fixes
- Simple features

## How It Works

```
┌─────────────────────────────────────────┐
│         DIRECT EXECUTION                 │
├─────────────────────────────────────────┤
│                                         │
│  1. UNDERSTAND                          │
│     └── Quick planning (internal)       │
│                                         │
│  2. IMPLEMENT                           │
│     └── Write code (TDD optional)       │
│                                         │
│  3. VERIFY                              │
│     └── Run tests, lint, build          │
│                                         │
│  4. DONE                                │
│     └── Report results                  │
│                                         │
└─────────────────────────────────────────┘
```

## Characteristics

| Aspect | Direct Mode |
|--------|-------------|
| Checkpoints | No |
| TDD | Optional (based on file type) |
| Parallel | No |
| Token overhead | Minimal |
| Session handoff | Unlikely (quick tasks) |

## Execution Flow

### 1. Quick Planning

Internal planning (not shown to user):

```python
def quick_plan(intent):
    """Minimal planning for simple tasks."""

    return QuickPlan(
        files=estimate_files(intent),
        approach=select_approach(intent),
        verification=get_verification_cmd(intent.project)
    )
```

### 2. Implementation

For each file:

```python
def implement(file, intent):
    """Implement changes for a single file."""

    # Check if TDD needed
    if should_use_tdd(intent.complexity, file.type):
        # Write test first
        test_file = write_test(file)
        run_test(test_file)  # Should fail

        # Implement
        implement_code(file)
        run_test(test_file)  # Should pass
    else:
        # Direct implementation
        implement_code(file)
```

### 3. Verification

Run full verification:

```python
def verify_all(project):
    """Run all verification commands."""

    results = {}

    # Tests
    results["tests"] = run_command(project.test_cmd)

    # Lint
    results["lint"] = run_command(project.lint_cmd)

    # Build (if exists)
    if project.build_cmd:
        results["build"] = run_command(project.build_cmd)

    return VerificationResult(
        all_passed=all(r.passed for r in results.values()),
        details=results
    )
```

### 4. Completion

Report results:

```
✓ Gotovo.

  Modificirano:
  • src/components/Button.tsx

  Verificirano:
  • Tests: 3/3 passing
  • Lint: no issues

  Commit? [Da] [Ne] [Pregledaj]
```

## TDD Decision

When to use TDD in Direct mode:

```python
def should_use_tdd(complexity, file_type):
    """Determine if TDD should be used."""

    # Skip for complexity 1
    if complexity <= 1:
        return False

    # Skip for config/boilerplate
    SKIP_TDD_PATTERNS = [
        "*.config.*",
        "*.json",
        "*.yaml",
        "*.md",
        "*.css",
        "*.env*"
    ]

    for pattern in SKIP_TDD_PATTERNS:
        if fnmatch(file_type, pattern):
            return False

    # Use TDD for complexity 2 logic files
    return complexity >= 2
```

## Failure Handling

Direct mode uses simplified failure handling:

```python
def handle_failure(error, attempt):
    """Handle failure in direct mode."""

    if attempt < 3:
        # Simple retry
        return Action("RETRY")

    # Ask user after 3 attempts
    return Action("ASK_USER", error=error)
```

## Mode Switch Detection

Monitor for unexpected complexity:

```python
def check_complexity_change(execution):
    """Check if task is more complex than expected."""

    # Track actual metrics
    actual_files = len(execution.files_touched)
    actual_errors = len(execution.errors_encountered)

    # Threshold for mode switch
    if actual_files > 5 or actual_errors > 3:
        return ModeSwitch(
            to="ORCHESTRATED",
            reason="Task more complex than expected"
        )

    return None
```

If mode switch needed:
1. Create emergency checkpoint
2. Notify user
3. Switch to Orchestrated mode
4. Continue with phases

## Output Examples

### Success

```
> /do Fix typo in header

Razumijem: Typo fix (complexity 1/5)

→ Fixing typo in Header.tsx... ✓
→ Verificiram...

✓ Gotovo.

  Modificirano:
  • src/components/Header.tsx (1 line)

  Verificirano:
  • Tests: passing
  • Lint: clean

  Commit? [Da] [Ne]
```

### With TDD

```
> /do Add email validation to signup form

Razumijem: Add validation (complexity 2/5)

→ Writing test for email validation...
→ Test fails (expected)
→ Implementing validation...
→ Test passes ✓
→ Verificiram...

✓ Gotovo.

  Modificirano:
  • src/components/SignupForm.tsx
  • src/components/SignupForm.test.tsx

  Verificirano:
  • Tests: 5/5 passing
  • Lint: clean

  Commit? [Da] [Ne] [Pregledaj]
```

### Failure Recovery

```
> /do Fix the button color

Razumijem: Style fix (complexity 1/5)

→ Updating Button styles...
→ Verificiram... ✗

  Lint error: unused import

→ Fixing lint issue...
→ Verificiram... ✓

✓ Gotovo.

  Modificirano:
  • src/components/Button.tsx

  Verificirano:
  • Lint: clean
```

## Integration

### With Strategist

Strategist selects Direct mode when complexity <= 2.

### With Failure Handler

Uses simplified retry logic (not full escalation).

### With State Manager

Updates state on completion:
- Files created/modified
- Evidence collected
- Execution status

## Comparison to Orchestrated

| Aspect | Direct | Orchestrated |
|--------|--------|--------------|
| Complexity | 1-2 | 3-5 |
| Phases | None | 2-5 |
| Checkpoints | None | After each phase |
| TDD | Optional | Required |
| Failure handling | Retry + Ask | Full escalation |
| Token usage | Low | Medium-High |
