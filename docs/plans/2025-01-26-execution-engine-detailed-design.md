# Execution Engine - Detailed Design

**Parent:** AGI-Like Interface Design
**Status:** Approved
**Date:** 2025-01-26

## Overview

Execution Engine izvršava taskove s TDD disciplinom, checkpoint-ima za kontinuitet, i robustnim failure handling-om.

```
┌─────────────────────────────────────────────────────────────────┐
│                    EXECUTION ENGINE                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐       │
│  │   DIRECT    │     │ORCHESTRATED │     │  CHECKPOINT │       │
│  │    MODE     │     │    MODE     │     │   MANAGER   │       │
│  │             │     │             │     │             │       │
│  │ Complexity  │     │ Complexity  │     │ State save  │       │
│  │    1-2      │     │    3-5      │     │ & restore   │       │
│  └─────────────┘     └─────────────┘     └─────────────┘       │
│                                                                 │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐       │
│  │  ADAPTIVE   │     │    TDD      │     │  FAILURE    │       │
│  │  SWITCHER   │     │  EXECUTOR   │     │  HANDLER    │       │
│  │             │     │             │     │             │       │
│  │ DIRECT ↔    │     │ RED→GREEN  │     │ Retry→Pivot │       │
│  │ ORCHESTRATED│     │ →REFACTOR   │     │ →Research   │       │
│  └─────────────┘     └─────────────┘     └─────────────┘       │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐       │
│  │                  HANDOFF MANAGER                     │       │
│  │                                                      │       │
│  │  Token monitoring → 80% trigger → Session handoff   │       │
│  └─────────────────────────────────────────────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. Execution Modes

### Mode Selection

```python
def select_mode(intent: EnrichedIntent) -> ExecutionMode:
    """Select execution mode based on complexity."""

    if intent.complexity <= 2:
        return DirectMode(intent)
    else:
        return OrchestratedMode(intent)
```

### Direct Mode (Complexity 1-2)

```python
class DirectMode:
    """Simple execution without phases or checkpoints."""

    def __init__(self, intent: EnrichedIntent):
        self.intent = intent
        self.use_tdd = False  # Skip TDD for simple tasks
        self.checkpoint_enabled = False

    def execute(self) -> ExecutionResult:
        """
        Flow:
        1. Understand → 2. Implement → 3. Verify → Done
        """

        # 1. Quick planning (internal, not shown to user)
        plan = self._quick_plan()

        # 2. Implement
        for file in plan.files:
            self._implement(file)

        # 3. Verify
        evidence = self._verify()

        if not evidence.passed:
            # Use failure handler
            return self._handle_failure(evidence)

        return ExecutionResult(
            success=True,
            evidence=evidence,
            mode="DIRECT"
        )

    def _quick_plan(self) -> QuickPlan:
        """Minimal planning for simple tasks."""

        return QuickPlan(
            files=self._estimate_files(),
            approach=self._select_approach(),
            verification=self._get_verification_cmd()
        )
```

### Orchestrated Mode (Complexity 3-5)

```python
class OrchestratedMode:
    """Phased execution with checkpoints and TDD."""

    def __init__(self, intent: EnrichedIntent):
        self.intent = intent
        self.use_tdd = True  # Always TDD for complex tasks
        self.checkpoint_enabled = True
        self.phases = self._decompose_into_phases()

    def execute(self) -> ExecutionResult:
        """
        Flow:
        For each phase:
          1. Checkpoint(start)
          2. TDD: RED → GREEN → REFACTOR
          3. Verify phase
          4. Checkpoint(complete)
        Final verification
        """

        results = []

        for phase in self.phases:
            # Start checkpoint
            self._checkpoint(phase.id, "starting")

            # Execute with TDD
            phase_result = self._execute_phase_tdd(phase)

            if not phase_result.success:
                return self._handle_phase_failure(phase, phase_result)

            # Complete checkpoint
            self._checkpoint(phase.id, "completed", phase_result.evidence)

            results.append(phase_result)

        # Final verification (all together)
        final_evidence = self._verify_all()

        return ExecutionResult(
            success=final_evidence.all_passed,
            evidence=final_evidence,
            mode="ORCHESTRATED",
            phases=results
        )

    def _decompose_into_phases(self) -> List[Phase]:
        """Break task into 2-5 phases."""

        if self.intent.sub_tasks:
            # Already decomposed by parser
            return self._sub_tasks_to_phases(self.intent.sub_tasks)

        # Auto-decompose
        if self.intent.complexity == 3:
            return self._decompose_3_phases()  # 2-3 phases
        elif self.intent.complexity == 4:
            return self._decompose_4_phases()  # 3-4 phases
        else:  # 5
            return self._decompose_5_phases()  # 4-5 phases
```

---

## 2. Adaptive Mode Switching

### When to Switch

```python
class AdaptiveSwitcher:
    """Handles mid-execution mode switches."""

    def __init__(self, execution: Execution):
        self.execution = execution
        self.original_complexity = execution.intent.complexity
        self.current_complexity = self.original_complexity

    def check_complexity_change(self) -> Optional[ModeSwitch]:
        """Check if complexity has increased significantly."""

        # Recalculate complexity based on actual progress
        actual_files = len(self.execution.files_touched)
        actual_time = self.execution.elapsed_time
        actual_errors = len(self.execution.errors_encountered)

        new_complexity = self._recalculate_complexity(
            actual_files,
            actual_time,
            actual_errors
        )

        # Check for significant increase (2+ levels)
        complexity_jump = new_complexity - self.original_complexity

        if complexity_jump >= 2:
            return ModeSwitch(
                from_mode="DIRECT",
                to_mode="ORCHESTRATED",
                reason=f"Complexity increased from {self.original_complexity} to {new_complexity}",
                action=self._create_switch_action()
            )

        return None

    def _create_switch_action(self) -> SwitchAction:
        """Create action plan for mode switch."""

        return SwitchAction(
            steps=[
                "1. Save current progress as checkpoint",
                "2. Analyze remaining work",
                "3. Decompose into phases",
                "4. Continue in ORCHESTRATED mode"
            ],
            checkpoint=self._create_emergency_checkpoint(),
            remaining_phases=self._estimate_remaining_phases()
        )
```

### Switch Execution

```python
def execute_mode_switch(switch: ModeSwitch, execution: Execution):
    """Execute the mode switch mid-task."""

    # 1. Create checkpoint with all current state
    checkpoint = CheckpointManager.create_full_checkpoint(
        execution,
        reason="mode_switch"
    )

    # 2. Log the switch
    log_mode_switch(
        original=switch.from_mode,
        new=switch.to_mode,
        reason=switch.reason,
        checkpoint_id=checkpoint.id
    )

    # 3. Notify user (brief)
    output(f"→ Task kompleksniji od očekivanog. Prebacujem na fazni pristup...")

    # 4. Create orchestrated execution from current state
    orchestrated = OrchestratedMode.from_checkpoint(checkpoint)

    # 5. Continue execution
    return orchestrated.execute()
```

---

## 3. Checkpoint System

### Checkpoint Structure

```python
@dataclass
class Checkpoint:
    """Complete state for instant resume."""

    id: str
    created_at: str
    reason: str  # "phase_complete", "mode_switch", "handoff", "error"

    # Task state
    task_id: str
    task_input: str
    mode: str  # "DIRECT" or "ORCHESTRATED"

    # Progress
    current_phase: Optional[int]
    total_phases: int
    completed_phases: List[PhaseResult]

    # Key decisions made
    decisions: List[Decision]

    # Files state
    files_created: List[str]
    files_modified: List[str]
    git_diff: str  # Actual diff for review/restore

    # Context
    context_summary: str  # Compressed context for next session
    tokens_used: int

    # Evidence collected
    evidence: List[Evidence]

    # Recovery info
    can_resume: bool
    resume_instructions: str
```

### Checkpoint Creation

```python
class CheckpointManager:

    @staticmethod
    def create_full_checkpoint(execution: Execution, reason: str) -> Checkpoint:
        """Create complete checkpoint for instant resume."""

        # Get git diff
        git_diff = run_command("git diff HEAD")

        # Compress context
        context_summary = compress_context(execution.context)

        # Collect all evidence
        evidence = execution.collect_all_evidence()

        checkpoint = Checkpoint(
            id=generate_checkpoint_id(),
            created_at=now_iso(),
            reason=reason,

            task_id=execution.task_id,
            task_input=execution.intent.raw_input,
            mode=execution.mode,

            current_phase=execution.current_phase,
            total_phases=len(execution.phases) if execution.phases else 1,
            completed_phases=execution.completed_phases,

            decisions=execution.decisions,

            files_created=execution.files_created,
            files_modified=execution.files_modified,
            git_diff=git_diff,

            context_summary=context_summary,
            tokens_used=execution.tokens_used,

            evidence=evidence,

            can_resume=True,
            resume_instructions=generate_resume_instructions(execution)
        )

        # Save to disk
        save_checkpoint(checkpoint)

        return checkpoint

    @staticmethod
    def restore_from_checkpoint(checkpoint_id: str) -> Execution:
        """Restore execution from checkpoint."""

        checkpoint = load_checkpoint(checkpoint_id)

        # Verify git state matches
        if not verify_git_state(checkpoint):
            raise CheckpointMismatchError(
                "Git state doesn't match checkpoint. "
                "Files may have been modified manually."
            )

        # Create execution from checkpoint
        execution = Execution.from_checkpoint(checkpoint)

        return execution
```

### Checkpoint File Format

```yaml
# .claude/checkpoints/chk-20250126-103000.yaml

id: "chk-20250126-103000"
created_at: "2025-01-26T10:30:00Z"
reason: "phase_complete"

task:
  id: "task-001"
  input: "Implement dark mode with system preference detection"
  mode: "ORCHESTRATED"

progress:
  current_phase: 2
  total_phases: 4
  completed:
    - phase: 1
      name: "ThemeProvider"
      evidence: "pnpm test → 3/3 passed"
    - phase: 2
      name: "useTheme hook"
      evidence: "pnpm test → 5/5 passed"

decisions:
  - question: "Theme storage"
    decision: "CSS variables"
    reason: "Better performance, no flash"

  - question: "Preference detection"
    decision: "prefers-color-scheme + localStorage override"
    reason: "Best of both worlds"

files:
  created:
    - "src/providers/ThemeProvider.tsx"
    - "src/hooks/useTheme.ts"
    - "src/hooks/useTheme.test.ts"
  modified:
    - "src/app/layout.tsx"

git_diff: |
  diff --git a/src/providers/ThemeProvider.tsx b/src/providers/ThemeProvider.tsx
  new file mode 100644
  ...

context_summary: |
  Implementing dark mode. Phases 1-2 complete (ThemeProvider, useTheme hook).
  Next: Phase 3 - Toggle component.
  Key: Using CSS variables, prefers-color-scheme for detection.
  Quirk: Project uses CSS modules, not Tailwind directly.

tokens_used: 45000

resume:
  can_resume: true
  instructions: |
    Continue with Phase 3: Toggle component
    - Create src/components/ThemeToggle.tsx
    - Use useTheme hook
    - Add to header/nav
    - Write tests
```

---

## 4. TDD Executor

### Adaptive TDD

```python
class TDDExecutor:
    """Executes code with TDD discipline when appropriate."""

    def should_use_tdd(self, complexity: int, file_type: str) -> bool:
        """Determine if TDD should be used."""

        # Always TDD for complexity 3+
        if complexity >= 3:
            return True

        # Skip TDD for config/boilerplate
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

        # Skip for complexity 1-2
        return False

    def execute_tdd(self, phase: Phase) -> PhaseResult:
        """Execute phase with TDD: RED → GREEN → REFACTOR."""

        results = []

        for unit in phase.units:
            # RED: Write failing test
            test_file = self._write_test(unit)
            red_result = self._run_test(test_file)

            if red_result.passed:
                # Test should fail initially!
                log_warning("Test passed before implementation - check test validity")

            # GREEN: Minimal implementation to pass
            impl_file = self._implement_minimal(unit)
            green_result = self._run_test(test_file)

            if not green_result.passed:
                # Failed to make test pass
                return self._handle_green_failure(unit, green_result)

            # REFACTOR: Clean up while keeping tests green
            self._refactor(impl_file)
            refactor_result = self._run_test(test_file)

            if not refactor_result.passed:
                # Refactoring broke something - revert
                self._revert_refactor(impl_file)
                log_warning("Refactoring broke tests - reverted")

            results.append(UnitResult(
                unit=unit,
                test_file=test_file,
                impl_file=impl_file,
                evidence=refactor_result
            ))

        return PhaseResult(
            phase=phase,
            success=True,
            units=results
        )
```

### TDD Templates

```python
def _write_test(self, unit: Unit) -> str:
    """Generate test file for unit."""

    # Get test template based on project
    template = self._get_test_template()

    test_content = template.render(
        unit_name=unit.name,
        expected_behavior=unit.expected_behavior,
        test_cases=unit.test_cases
    )

    test_file = f"{unit.path}.test.ts"
    write_file(test_file, test_content)

    return test_file

# Example template (Vitest)
VITEST_TEMPLATE = """
import { describe, it, expect } from 'vitest';
import { {{ unit_name }} } from './{{ unit_name }}';

describe('{{ unit_name }}', () => {
  {% for test in test_cases %}
  it('{{ test.description }}', () => {
    {{ test.arrangement }}

    const result = {{ test.action }};

    expect(result).{{ test.assertion }};
  });
  {% endfor %}
});
"""
```

---

## 5. Failure Handler

### Escalation Levels

```python
class FailureHandler:
    """
    Handle failures with escalating strategies:
    Level 1: Retry (up to 3x)
    Level 2: Pivot (try different approach)
    Level 3: Research (read more code, understand better)
    Level 4: Checkpoint/Ask (save state, ask user)
    """

    def __init__(self):
        self.retry_count = 0
        self.pivot_count = 0
        self.research_count = 0
        self.max_retries = 3
        self.max_pivots = 3
        self.max_research = 2

    def handle(self, failure: Failure, execution: Execution) -> HandlerResult:
        """Handle failure with escalating strategies."""

        # Level 1: Retry
        if self.retry_count < self.max_retries:
            return self._retry(failure, execution)

        # Level 2: Pivot
        if self.pivot_count < self.max_pivots:
            return self._pivot(failure, execution)

        # Level 3: Research
        if self.research_count < self.max_research:
            return self._research(failure, execution)

        # Level 4: Checkpoint and ask
        return self._checkpoint_and_ask(failure, execution)
```

### Level 1: Retry

```python
def _retry(self, failure: Failure, execution: Execution) -> HandlerResult:
    """Simple retry - maybe transient error."""

    self.retry_count += 1

    log(f"Retry {self.retry_count}/{self.max_retries}: {failure.summary}")

    # Small delay to avoid hammering
    time.sleep(1)

    # Retry the failed operation
    result = execution.retry_last_operation()

    if result.success:
        self.retry_count = 0  # Reset on success
        return HandlerResult(
            action="CONTINUE",
            message="Retry successful"
        )

    return HandlerResult(
        action="ESCALATE",
        message=f"Retry {self.retry_count} failed"
    )
```

### Level 2: Pivot

```python
def _pivot(self, failure: Failure, execution: Execution) -> HandlerResult:
    """Try a different approach."""

    self.pivot_count += 1
    self.retry_count = 0  # Reset retries for new approach

    log(f"Pivot {self.pivot_count}/{self.max_pivots}: Trying alternative approach")

    # Analyze failure to find alternatives
    alternatives = self._find_alternatives(failure, execution)

    if not alternatives:
        return HandlerResult(
            action="ESCALATE",
            message="No alternative approaches found"
        )

    # Select best alternative
    selected = alternatives[0]

    output(f"→ Pokušavam drugačiji pristup: {selected.description}")

    # Apply alternative
    result = execution.apply_alternative(selected)

    if result.success:
        self.pivot_count = 0
        return HandlerResult(
            action="CONTINUE",
            message=f"Pivot successful: {selected.description}"
        )

    return HandlerResult(
        action="ESCALATE",
        message=f"Pivot to '{selected.description}' failed"
    )

def _find_alternatives(self, failure: Failure, execution: Execution) -> List[Alternative]:
    """Find alternative approaches based on failure type."""

    alternatives = []

    # Check memory for similar failures and solutions
    similar_failures = memory.find_similar_failures(failure)
    for sf in similar_failures:
        if sf.solution_worked:
            alternatives.append(Alternative(
                description=sf.solution,
                confidence=sf.confidence,
                source="memory"
            ))

    # Check for common alternatives based on error type
    if failure.type == "IMPORT_ERROR":
        alternatives.append(Alternative(
            description="Check for missing dependency, install if needed",
            confidence=0.8,
            source="heuristic"
        ))

    elif failure.type == "TYPE_ERROR":
        alternatives.append(Alternative(
            description="Review type definitions, check for mismatches",
            confidence=0.7,
            source="heuristic"
        ))

    elif failure.type == "TEST_FAILURE":
        alternatives.append(Alternative(
            description="Review test expectations, check for async issues",
            confidence=0.6,
            source="heuristic"
        ))

    # Sort by confidence
    return sorted(alternatives, key=lambda a: a.confidence, reverse=True)
```

### Level 3: Research

```python
def _research(self, failure: Failure, execution: Execution) -> HandlerResult:
    """Deep dive - read more code, understand the problem better."""

    self.research_count += 1
    self.pivot_count = 0
    self.retry_count = 0

    log(f"Research {self.research_count}/{self.max_research}: Deep analysis")

    output("→ Analiziram problem detaljnije...")

    # 1. Read related files
    related_files = self._find_related_files(failure, execution)
    for file in related_files[:5]:  # Limit to 5
        content = read_file(file)
        execution.add_context(file, content)

    # 2. Check for patterns in codebase
    patterns = self._analyze_codebase_patterns(failure)

    # 3. Search for similar code that works
    working_examples = self._find_working_examples(failure)

    # 4. Reformulate approach with new understanding
    new_approach = self._formulate_new_approach(
        failure,
        patterns,
        working_examples
    )

    if new_approach:
        output(f"→ Pronašao novi pristup: {new_approach.summary}")

        result = execution.apply_approach(new_approach)

        if result.success:
            # Learn from this!
            memory.store_learning(Learning(
                type="gotcha",
                problem=failure.description,
                solution=new_approach.description,
                source="research"
            ))

            return HandlerResult(
                action="CONTINUE",
                message="Research successful"
            )

    return HandlerResult(
        action="ESCALATE",
        message="Research did not find solution"
    )
```

### Level 4: Checkpoint and Ask

```python
def _checkpoint_and_ask(self, failure: Failure, execution: Execution) -> HandlerResult:
    """Save state and ask user for help."""

    # Create detailed checkpoint
    checkpoint = CheckpointManager.create_full_checkpoint(
        execution,
        reason="stuck"
    )

    # Create stuck report
    stuck_report = self._create_stuck_report(failure, execution)

    # Output to user
    output(f"""
⚠️  Zaglavljen sam na ovom problemu.

**Problem:**
{failure.description}

**Što sam pokušao:**
- Retry: {self.max_retries}x
- Pivot: {self.max_pivots} različitih pristupa
- Research: Analizirao povezani kod

**Checkpoint spremljen:**
{checkpoint.id}

**Opcije:**
[A] Pokaži mi detalje greške
[B] Predloži rješenje (slobodni unos)
[C] Preskoči ovaj dio i nastavi
[D] Odustani od taska
""")

    return HandlerResult(
        action="ASK_USER",
        checkpoint=checkpoint,
        stuck_report=stuck_report
    )

def _create_stuck_report(self, failure: Failure, execution: Execution) -> StuckReport:
    """Create detailed report for debugging."""

    return StuckReport(
        failure=failure,
        attempts=[
            *self._get_retry_attempts(),
            *self._get_pivot_attempts(),
            *self._get_research_findings()
        ],
        relevant_files=execution.files_touched,
        error_traces=failure.traces,
        suggestions=self._generate_suggestions(failure)
    )
```

---

## 6. Handoff Manager

### Token Monitoring

```python
class HandoffManager:
    """Manages session handoff at 80% token usage."""

    HANDOFF_THRESHOLD = 0.80  # 80%
    WARNING_THRESHOLD = 0.70  # 70%

    def __init__(self, token_budget: int):
        self.token_budget = token_budget
        self.tokens_used = 0
        self.warned = False

    def update_usage(self, tokens: int):
        """Update token usage and check thresholds."""

        self.tokens_used += tokens
        percentage = self.tokens_used / self.token_budget

        # Warning at 70%
        if percentage >= self.WARNING_THRESHOLD and not self.warned:
            self.warned = True
            self._start_context_compression()

        # Handoff at 80%
        if percentage >= self.HANDOFF_THRESHOLD:
            return self._initiate_handoff()

        return None

    def _start_context_compression(self):
        """Start compressing context to extend runway."""

        log("Token usage at 70% - starting context compression")

        # Summarize old context
        # Remove verbose outputs
        # Keep only essential information

    def _initiate_handoff(self) -> Handoff:
        """Initiate handoff to new session."""

        log("Token usage at 80% - initiating handoff")

        return Handoff(
            reason="token_limit",
            checkpoint=CheckpointManager.create_full_checkpoint(
                self.execution,
                reason="handoff"
            ),
            next_session_context=self._create_next_session_context()
        )
```

### Handoff Execution

```python
def execute_handoff(handoff: Handoff, execution: Execution):
    """Execute the session handoff."""

    # 1. Complete current phase if possible
    if execution.current_phase_near_complete():
        execution.complete_current_phase()

    # 2. Create checkpoint
    checkpoint = handoff.checkpoint

    # 3. Create next-session.md
    next_session = create_next_session_file(checkpoint, execution)

    # 4. Git commit progress
    commit_progress(execution, "Handoff checkpoint")

    # 5. Output to user
    output(f"""
→ Nastavljam u novoj sesiji...

Progress: {execution.completed_phases}/{execution.total_phases} faza
Checkpoint: {checkpoint.id}

Za nastavak, u novoj sesiji pokreni:
  /do --continue

Ili će se automatski nastaviti ako koristiš overnight mode.
""")

    # 6. Update state
    update_state(
        status="handoff_pending",
        checkpoint_id=checkpoint.id,
        resume_instructions=next_session.instructions
    )
```

### Next Session File

```python
def create_next_session_file(checkpoint: Checkpoint, execution: Execution) -> NextSession:
    """Create bootstrap file for next session."""

    content = f"""# Next Session Context

## Quick Start
Nastavljam task: "{execution.intent.raw_input}"
Progress: {len(checkpoint.completed_phases)}/{checkpoint.total_phases} faza

## Current State
- Status: Handoff - waiting for new session
- Next: Phase {checkpoint.current_phase + 1}
- Checkpoint: {checkpoint.id}

## Key Decisions Made
{format_decisions(checkpoint.decisions)}

## Completed Phases
{format_completed_phases(checkpoint.completed_phases)}

## Next Phase
{format_next_phase(execution.phases[checkpoint.current_phase])}

## Project Context
- Stack: {execution.project.stack}
- Test: {execution.project.test_cmd}
- Quirks: {format_quirks(execution.project.quirks)}

## Files Modified
{format_files(checkpoint.files_created, checkpoint.files_modified)}

## Resume Instructions
1. Load checkpoint {checkpoint.id}
2. Verify git state matches
3. Continue with Phase {checkpoint.current_phase + 1}
4. Follow TDD discipline
5. Checkpoint after phase completion
"""

    write_file(".claude/auto-execution/next-session.md", content)

    return NextSession(
        file=".claude/auto-execution/next-session.md",
        checkpoint_id=checkpoint.id,
        instructions=content
    )
```

---

## 7. User Output

### Progress Display

```python
class OutputFormatter:
    """Formats execution output for user."""

    def phase_start(self, phase: Phase):
        output(f"→ {phase.name}...")

    def phase_complete(self, phase: Phase, evidence: Evidence):
        output(f"→ {phase.name}... ✓")

    def phase_failed(self, phase: Phase, error: str):
        output(f"→ {phase.name}... ✗")
        output(f"  Error: {error}")

    def task_complete(self, result: ExecutionResult):
        output(f"""
✓ Gotovo.

  Kreirano:
{format_file_list(result.files_created)}

  Modificirano:
{format_file_list(result.files_modified)}

  Verificirano:
  • Tests: {result.evidence.tests}
  • Build: {result.evidence.build}
  • Lint: {result.evidence.lint}

  Commit? [Da] [Ne] [Pregledaj]
""")

    def progress_bar(self, current: int, total: int):
        percentage = current / total
        filled = int(percentage * 20)
        bar = "━" * filled + "░" * (20 - filled)
        output(f"Phase {current}/{total}: {bar} {int(percentage*100)}%")
```

---

## 8. File Locations

```
execution/
├── direct-mode.md           # Simple execution
├── orchestrated-mode.md     # Phased execution
├── adaptive-switcher.md     # Mode switching
├── checkpoint.md            # Checkpoint management
├── tdd-executor.md          # TDD implementation
├── failure-handler.md       # Failure escalation
└── handoff.md               # Session handoff
```

---

## 9. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Task completion rate | >90% | Tasks finished without user help |
| Mode switch accuracy | >85% | Correct switches when needed |
| Checkpoint recovery | 100% | Successful resumes from checkpoint |
| TDD compliance | 100% | Tests before code for complexity 3+ |
| Handoff smoothness | >95% | Seamless session continuations |
| Failure recovery | >70% | Failures resolved without user |
