# Orchestrated Executor

Executes complex tasks (complexity 3-5) with phased execution, TDD, and checkpoints.

## When to Use

- Complexity 3-5 tasks
- Multi-file changes
- Tasks requiring verification between phases
- Long-running tasks that may need session handoff

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                   ORCHESTRATED EXECUTION                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                      PHASE LOOP                          │   │
│  │                                                          │   │
│  │  For each phase (2-5):                                   │   │
│  │                                                          │   │
│  │    1. CHECKPOINT (start)                                 │   │
│  │       └── Save state before phase                        │   │
│  │                                                          │   │
│  │    2. TDD CYCLE                                          │   │
│  │       ├── RED: Write failing test                        │   │
│  │       ├── GREEN: Implement to pass                       │   │
│  │       └── REFACTOR: Clean up                             │   │
│  │                                                          │   │
│  │    3. VERIFY                                             │   │
│  │       └── Run tests, lint, type-check                    │   │
│  │                                                          │   │
│  │    4. CHECKPOINT (complete)                              │   │
│  │       └── Save evidence, update progress                 │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   FINAL VERIFICATION                      │   │
│  │                                                          │   │
│  │  • All tests pass                                        │   │
│  │  • Lint clean                                            │   │
│  │  • Build succeeds                                        │   │
│  │  • Types check                                           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Characteristics

| Aspect | Orchestrated Mode |
|--------|-------------------|
| Complexity | 3-5 |
| Phases | 2-5 (based on complexity) |
| Checkpoints | After each phase |
| TDD | Required |
| Parallel tasks | Optional per phase |
| Token overhead | Medium-High |
| Session handoff | Likely for complexity 4-5 |

## Phase Decomposition

### Rules

```python
def decompose_into_phases(intent: ClassifiedIntent) -> List[Phase]:
    """Break task into executable phases."""

    # Check if parser already decomposed
    if intent.sub_tasks:
        return sub_tasks_to_phases(intent.sub_tasks)

    # Auto-decompose based on complexity
    complexity = intent.classification.complexity

    if complexity == 3:
        return decompose_3_phases(intent)  # 2-3 phases
    elif complexity == 4:
        return decompose_4_phases(intent)  # 3-4 phases
    else:  # 5
        return decompose_5_phases(intent)  # 4-5 phases
```

### Phase Count Guidelines

| Complexity | Phases | Typical Structure |
|------------|--------|-------------------|
| 3 | 2-3 | Setup → Core → Polish |
| 4 | 3-4 | Setup → Core A → Core B → Integration |
| 5 | 4-5 | Setup → Core modules → Integration → Testing → Polish |

### Example Decomposition

```yaml
# Task: "Add user authentication with Google OAuth"
# Complexity: 4

phases:
  - id: 1
    name: "Auth Provider Setup"
    description: "Set up NextAuth with Google provider"
    files:
      - "src/app/api/auth/[...nextauth]/route.ts"
      - "src/lib/auth.ts"
    test_focus: "Provider configuration"
    estimated_tokens: 5000

  - id: 2
    name: "Session Hook"
    description: "Create useSession hook with types"
    files:
      - "src/hooks/useSession.ts"
      - "src/types/auth.ts"
    test_focus: "Hook behavior"
    estimated_tokens: 3000

  - id: 3
    name: "Protected Routes"
    description: "Add middleware for route protection"
    files:
      - "src/middleware.ts"
      - "src/app/(auth)/layout.tsx"
    test_focus: "Route protection"
    estimated_tokens: 4000

  - id: 4
    name: "UI Components"
    description: "Login/logout buttons, user menu"
    files:
      - "src/components/auth/LoginButton.tsx"
      - "src/components/auth/UserMenu.tsx"
    test_focus: "Component rendering"
    estimated_tokens: 3000
```

## Execution Flow

### Main Loop

```python
def execute(self) -> ExecutionResult:
    """Execute task in phases with TDD and checkpoints."""

    results = []

    for phase in self.phases:
        # Check token budget
        if should_handoff():
            return request_handoff(phase)

        # Execute phase
        phase_result = execute_phase(phase)

        if not phase_result.success:
            return handle_phase_failure(phase, phase_result)

        results.append(phase_result)

    # Final verification
    final_evidence = verify_all()

    return ExecutionResult(
        success=final_evidence.all_passed,
        evidence=final_evidence,
        mode="ORCHESTRATED",
        phases=results
    )
```

### Phase Execution

```python
def execute_phase(phase: Phase) -> PhaseResult:
    """Execute single phase with TDD cycle."""

    # 1. Start checkpoint
    checkpoint_start(phase.id)

    # 2. Announce phase
    output(f"→ Faza {phase.id}/{total_phases}: {phase.name}")

    # 3. TDD Cycle
    tdd_result = execute_tdd_cycle(phase)

    if not tdd_result.success:
        return PhaseResult(
            phase_id=phase.id,
            success=False,
            error=tdd_result.error
        )

    # 4. Phase verification
    evidence = verify_phase(phase)

    if not evidence.passed:
        return PhaseResult(
            phase_id=phase.id,
            success=False,
            error=evidence.errors
        )

    # 5. Complete checkpoint
    checkpoint_complete(phase.id, evidence)

    # 6. Report progress
    output(f"  ✓ {phase.name} ({evidence.tests_passed}/{evidence.tests_total} tests)")

    return PhaseResult(
        phase_id=phase.id,
        success=True,
        evidence=evidence,
        files=phase.files
    )
```

### TDD Cycle

```python
def execute_tdd_cycle(phase: Phase) -> TDDResult:
    """Execute RED → GREEN → REFACTOR cycle."""

    # RED: Write failing tests
    output(f"  → RED: Writing tests...")
    test_result = write_tests(phase)

    if test_result.error:
        return TDDResult(success=False, error=test_result.error)

    # Run tests - should fail
    red_run = run_tests(phase.test_files)
    if red_run.all_passed:
        output(f"  ! Tests already pass - checking coverage...")
        # May need additional tests

    # GREEN: Implement to pass
    output(f"  → GREEN: Implementing...")
    impl_result = implement(phase)

    if impl_result.error:
        return TDDResult(success=False, error=impl_result.error)

    # Run tests - should pass
    green_run = run_tests(phase.test_files)
    if not green_run.all_passed:
        # Enter fix loop
        fix_result = fix_failing_tests(phase, green_run)
        if not fix_result.success:
            return TDDResult(success=False, error=fix_result.error)

    # REFACTOR: Clean up
    output(f"  → REFACTOR: Cleaning up...")
    refactor_result = refactor(phase)

    # Verify tests still pass
    final_run = run_tests(phase.test_files)
    if not final_run.all_passed:
        return TDDResult(
            success=False,
            error="Tests failed after refactor"
        )

    return TDDResult(
        success=True,
        tests_passed=final_run.passed_count,
        tests_total=final_run.total_count
    )
```

## Checkpoint Integration

### When to Checkpoint

- Before each phase starts
- After each phase completes
- Before session handoff
- On recoverable errors

### Checkpoint Content

```python
def checkpoint_complete(phase_id: int, evidence: Evidence):
    """Create checkpoint after phase completion."""

    checkpoint = Checkpoint(
        id=generate_checkpoint_id(),
        reason="phase_complete",
        phase=phase_id,
        total_phases=len(phases),
        evidence=evidence,
        files_modified=get_modified_files(),
        git_diff=get_git_diff(),
        context_summary=compress_context(),
        resume_instructions=generate_resume_instructions(phase_id + 1)
    )

    save_checkpoint(checkpoint)
    update_state(current_phase=phase_id, status="phase_complete")
```

## Failure Handling

### Phase Failure

```python
def handle_phase_failure(phase: Phase, result: PhaseResult) -> ExecutionResult:
    """Handle failure in a phase."""

    # Create error checkpoint
    checkpoint_error(phase.id, result.error)

    # Escalate to failure handler
    resolution = failure_handler.handle(
        error=result.error,
        phase=phase,
        context=get_current_context()
    )

    if resolution.action == "RETRY":
        return execute_phase(phase)

    if resolution.action == "PIVOT":
        # Try alternative approach
        phase.approach = resolution.alternative
        return execute_phase(phase)

    if resolution.action == "RESEARCH":
        # Invoke research skill
        research_result = invoke_skill("deep-research", phase.problem)
        if research_result.solution:
            phase.hints.append(research_result.solution)
            return execute_phase(phase)

    if resolution.action == "ASK":
        # Ask user
        return request_user_help(phase, result.error)

    # Give up
    return ExecutionResult(
        success=False,
        error=result.error,
        mode="ORCHESTRATED",
        failed_at_phase=phase.id
    )
```

## Token Management

### Budget Tracking

```python
def check_token_budget(phase: Phase) -> TokenStatus:
    """Check if we have budget for next phase."""

    current_usage = get_current_token_usage()
    estimated_needed = phase.estimated_tokens

    remaining = MAX_TOKENS - current_usage
    percentage = current_usage / MAX_TOKENS

    if percentage >= 0.8:
        return TokenStatus(
            should_handoff=True,
            reason="80% threshold reached"
        )

    if remaining < estimated_needed:
        return TokenStatus(
            should_handoff=True,
            reason="Insufficient tokens for next phase"
        )

    return TokenStatus(should_handoff=False)
```

### Handoff Preparation

```python
def request_handoff(at_phase: Phase) -> ExecutionResult:
    """Prepare for session handoff."""

    # Complete current atomic operation if any

    # Create handoff checkpoint
    checkpoint = Checkpoint(
        id=generate_checkpoint_id(),
        reason="handoff",
        phase=at_phase.id,
        resume_instructions=f"""
Continue from Phase {at_phase.id}: {at_phase.name}

Remaining phases:
{format_remaining_phases(at_phase.id)}

Key context:
{compress_context()}
"""
    )

    save_checkpoint(checkpoint)

    # Signal orchestrator
    request_handoff_signal()

    return ExecutionResult(
        success=True,
        mode="ORCHESTRATED",
        status="HANDOFF_REQUESTED",
        checkpoint_id=checkpoint.id
    )
```

## Output Examples

### Successful Execution

```
> /do Add user authentication with Google OAuth

Razumijem: Add authentication (complexity 4/5)
Mode: ORCHESTRATED (4 faze)

→ Faza 1/4: Auth Provider Setup
  → RED: Writing tests...
  → GREEN: Implementing...
  → REFACTOR: Cleaning up...
  ✓ Auth Provider Setup (3/3 tests)

→ Faza 2/4: Session Hook
  → RED: Writing tests...
  → GREEN: Implementing...
  → REFACTOR: Cleaning up...
  ✓ Session Hook (4/4 tests)

→ Faza 3/4: Protected Routes
  → RED: Writing tests...
  → GREEN: Implementing...
  → REFACTOR: Cleaning up...
  ✓ Protected Routes (5/5 tests)

→ Faza 4/4: UI Components
  → RED: Writing tests...
  → GREEN: Implementing...
  → REFACTOR: Cleaning up...
  ✓ UI Components (6/6 tests)

→ Finalna verifikacija...

✓ Gotovo.

  Kreirano:
  • src/app/api/auth/[...nextauth]/route.ts
  • src/lib/auth.ts
  • src/hooks/useSession.ts
  • src/middleware.ts
  • src/components/auth/LoginButton.tsx
  • src/components/auth/UserMenu.tsx

  Verificirano:
  • Tests: 18/18 passing
  • Lint: no issues
  • Types: OK
  • Build: OK

  Commit? [Da] [Ne] [Pregledaj]
```

### With Handoff

```
> /do Major API refactoring

Razumijem: API refactor (complexity 5/5)
Mode: ORCHESTRATED (5 faza)

→ Faza 1/5: API Schema Changes
  ✓ API Schema Changes (8/8 tests)

→ Faza 2/5: Route Handlers
  ✓ Route Handlers (12/12 tests)

→ Faza 3/5: Middleware Updates
  ! Token limit approaching (82%)
  → Creating checkpoint...
  → Signaling handoff...

══════════════════════════════════════════════════════════════
 SESSION HANDOFF
══════════════════════════════════════════════════════════════

 Progress: 2/5 phases complete
 Checkpoint: chk-20250126-143000

 Resume command:
 claude-agi --continue

 Or manually:
 /auto-execute --continue

══════════════════════════════════════════════════════════════
```

## Integration

### With Checkpoint Manager

Uses checkpoint-manager.sh for:
- Creating phase checkpoints
- Restoring from handoff
- Error recovery

### With TDD Executor

Delegates TDD cycle to tdd-executor skill.

### With Failure Handler

Escalates failures through failure-handler skill.

### With Handoff Manager

Coordinates with handoff-manager for session continuity.

## Comparison to Direct Mode

| Aspect | Direct | Orchestrated |
|--------|--------|--------------|
| Complexity | 1-2 | 3-5 |
| Phases | None | 2-5 |
| Checkpoints | None | After each phase |
| TDD | Optional | Required |
| Failure handling | Simple retry | Full escalation |
| Session handoff | Unlikely | Likely for 4-5 |
| User feedback | End only | After each phase |
| Token usage | Low | Medium-High |
