# Execution Strategist

Selects optimal execution strategy (DIRECT vs ORCHESTRATED) and plans phases.

## When to Use

- After Resolver approves intent (PROCEED)
- Before execution begins
- When mode switch is needed during execution

## What It Does

```
Resolved Intent
      │
      ▼
┌─────────────────────────────────────────────┐
│              STRATEGIST                      │
├─────────────────────────────────────────────┤
│                                             │
│  1. Select Mode                             │
│     → Complexity 1-2 = DIRECT               │
│     → Complexity 3-5 = ORCHESTRATED         │
│                                             │
│  2. Plan Phases (if ORCHESTRATED)           │
│     → Decompose into 2-5 phases             │
│     → Identify dependencies                 │
│                                             │
│  3. Estimate Resources                      │
│     → Token budget per phase                │
│     → Likelihood of handoff                 │
│                                             │
│  4. Configure Execution                     │
│     → TDD settings                          │
│     → Checkpoint frequency                  │
│                                             │
└─────────────────────────────────────────────┘
      │
      ▼
Execution Strategy
```

## Strategy Selection

### Mode Decision

```python
def select_strategy(intent: ClassifiedIntent) -> Strategy:
    """Select optimal execution strategy."""

    complexity = intent.classification.complexity

    if complexity <= 2:
        return DirectStrategy(intent)
    else:
        return OrchestratedStrategy(intent)
```

### Direct Strategy

```python
class DirectStrategy(Strategy):
    """For complexity 1-2: simple execution loop."""

    def __init__(self, intent: ClassifiedIntent):
        self.intent = intent
        self.mode = "DIRECT"

        # Configuration
        self.checkpoints_enabled = False
        self.tdd_required = False
        self.parallel_enabled = False

        # Optional TDD for complexity 2 + backend
        if intent.classification.complexity == 2:
            if intent.classification.work_type == "BACKEND":
                self.tdd_required = True

    def get_execution_plan(self) -> ExecutionPlan:
        """Get simple execution plan."""

        return ExecutionPlan(
            mode="DIRECT",
            phases=[],  # No phases for direct
            steps=[
                "1. Understand task",
                "2. Implement (TDD if applicable)",
                "3. Verify",
                "4. Done"
            ],
            estimated_tokens=self._estimate_tokens(),
            handoff_likely=False
        )

    def _estimate_tokens(self) -> int:
        """Estimate token usage."""

        # Base cost
        base = 5000

        # Per file estimate
        file_cost = len(self.intent.references) * 2000

        # TDD overhead
        if self.tdd_required:
            file_cost *= 1.5

        return int(base + file_cost)
```

### Orchestrated Strategy

```python
class OrchestratedStrategy(Strategy):
    """For complexity 3-5: phased execution with checkpoints."""

    def __init__(self, intent: ClassifiedIntent):
        self.intent = intent
        self.mode = "ORCHESTRATED"

        # Configuration
        self.checkpoints_enabled = True
        self.tdd_required = True
        self.parallel_enabled = self._can_parallelize()

        # Decompose into phases
        self.phases = self._decompose()

    def get_execution_plan(self) -> ExecutionPlan:
        """Get phased execution plan."""

        return ExecutionPlan(
            mode="ORCHESTRATED",
            phases=self.phases,
            steps=self._generate_steps(),
            estimated_tokens=self._estimate_tokens(),
            handoff_likely=self._is_handoff_likely()
        )

    def _decompose(self) -> List[Phase]:
        """Decompose into 2-5 phases."""

        # Check if parser already decomposed
        if self.intent.sub_tasks:
            return self._sub_tasks_to_phases(self.intent.sub_tasks)

        # Auto-decompose based on complexity
        complexity = self.intent.classification.complexity

        if complexity == 3:
            return self._decompose_medium()
        elif complexity == 4:
            return self._decompose_large()
        else:  # 5
            return self._decompose_xlarge()

    def _can_parallelize(self) -> bool:
        """Check if phases can be parallelized."""

        # Need at least 2 phases
        if len(self.phases) < 2:
            return False

        # Check for dependencies
        for phase in self.phases:
            if phase.depends_on:
                return False

        return True
```

## Phase Decomposition

### Decomposition Strategies

```python
def _decompose_medium(self) -> List[Phase]:
    """Decompose complexity 3 into 2-3 phases."""

    work_type = self.intent.classification.work_type

    if work_type == "FRONTEND":
        return [
            Phase(
                id=1,
                name="Components",
                description="Create/modify UI components",
                estimated_tokens=6000
            ),
            Phase(
                id=2,
                name="Logic & State",
                description="Add business logic and state management",
                estimated_tokens=5000
            ),
            Phase(
                id=3,
                name="Integration",
                description="Connect components, add tests",
                estimated_tokens=4000
            )
        ]

    elif work_type == "BACKEND":
        return [
            Phase(
                id=1,
                name="Data Layer",
                description="Models, schemas, database changes",
                estimated_tokens=5000
            ),
            Phase(
                id=2,
                name="Business Logic",
                description="Services, handlers, validation",
                estimated_tokens=6000
            ),
            Phase(
                id=3,
                name="API & Tests",
                description="Routes, integration tests",
                estimated_tokens=4000
            )
        ]

    else:  # FULLSTACK
        return [
            Phase(
                id=1,
                name="Backend",
                description="API, data layer changes",
                estimated_tokens=6000
            ),
            Phase(
                id=2,
                name="Frontend",
                description="UI components and state",
                estimated_tokens=6000
            ),
            Phase(
                id=3,
                name="Integration",
                description="Connect frontend to backend, tests",
                estimated_tokens=3000
            )
        ]


def _decompose_large(self) -> List[Phase]:
    """Decompose complexity 4 into 3-4 phases."""

    # Similar structure but more phases
    phases = self._decompose_medium()

    # Add setup phase at beginning
    phases.insert(0, Phase(
        id=0,
        name="Setup",
        description="Dependencies, configuration, scaffolding",
        estimated_tokens=3000
    ))

    # Renumber phases
    for i, phase in enumerate(phases):
        phase.id = i + 1

    return phases


def _decompose_xlarge(self) -> List[Phase]:
    """Decompose complexity 5 into 4-5 phases."""

    phases = self._decompose_large()

    # Add polish phase at end
    phases.append(Phase(
        id=len(phases) + 1,
        name="Polish",
        description="Error handling, edge cases, documentation",
        estimated_tokens=4000
    ))

    return phases
```

### Sub-task to Phase Conversion

```python
def _sub_tasks_to_phases(self, sub_tasks: List[SubTask]) -> List[Phase]:
    """Convert parser-identified sub-tasks to phases."""

    phases = []

    for i, task in enumerate(sub_tasks):
        phase = Phase(
            id=i + 1,
            name=task.name,
            description=task.description,
            files=task.files,
            depends_on=[dep.id for dep in task.dependencies],
            estimated_tokens=self._estimate_task_tokens(task)
        )
        phases.append(phase)

    return phases
```

## Resource Estimation

```python
def _estimate_tokens(self) -> int:
    """Estimate total token usage."""

    base = 3000  # Context, planning overhead

    phase_tokens = sum(p.estimated_tokens for p in self.phases)

    # Checkpoint overhead
    checkpoint_overhead = len(self.phases) * 500

    # TDD overhead (about 50% extra)
    tdd_overhead = phase_tokens * 0.5 if self.tdd_required else 0

    return int(base + phase_tokens + checkpoint_overhead + tdd_overhead)


def _is_handoff_likely(self) -> bool:
    """Estimate if session handoff will be needed."""

    estimated = self._estimate_tokens()
    threshold = 80000  # 80% of typical 100k limit

    return estimated > threshold
```

## Execution Configuration

```python
def configure_execution(strategy: Strategy) -> ExecutionConfig:
    """Configure execution parameters."""

    config = ExecutionConfig()

    # TDD settings
    config.tdd = TDDConfig(
        enabled=strategy.tdd_required,
        framework=detect_test_framework(),
        coverage_threshold=80 if strategy.mode == "ORCHESTRATED" else 0
    )

    # Checkpoint settings
    config.checkpoints = CheckpointConfig(
        enabled=strategy.checkpoints_enabled,
        frequency="per_phase" if strategy.mode == "ORCHESTRATED" else "none",
        include_git_diff=True
    )

    # Verification settings
    config.verification = VerificationConfig(
        run_tests=True,
        run_lint=True,
        run_typecheck=strategy.intent.project.has_types,
        run_build=strategy.mode == "ORCHESTRATED"
    )

    # Handoff settings
    config.handoff = HandoffConfig(
        threshold=0.80,
        enabled=strategy._is_handoff_likely()
    )

    return config
```

## Output Structure

```typescript
interface ExecutionPlan {
  mode: "DIRECT" | "ORCHESTRATED";
  phases: Phase[];
  steps: string[];
  estimated_tokens: number;
  handoff_likely: boolean;
  config: ExecutionConfig;
}

interface Phase {
  id: number;
  name: string;
  description: string;
  files?: string[];
  depends_on?: number[];
  estimated_tokens: number;
}

interface ExecutionConfig {
  tdd: {
    enabled: boolean;
    framework: string;
    coverage_threshold: number;
  };
  checkpoints: {
    enabled: boolean;
    frequency: "none" | "per_phase" | "per_unit";
  };
  verification: {
    run_tests: boolean;
    run_lint: boolean;
    run_typecheck: boolean;
    run_build: boolean;
  };
  handoff: {
    threshold: number;
    enabled: boolean;
  };
}
```

## Example Strategies

### Direct (Complexity 2)

```yaml
input: "Add email validation to signup form"
complexity: 2

strategy:
  mode: "DIRECT"
  phases: []
  steps:
    - "1. Understand task"
    - "2. Write validation test (optional TDD)"
    - "3. Implement validation"
    - "4. Verify"
    - "5. Done"
  estimated_tokens: 8000
  handoff_likely: false

  config:
    tdd:
      enabled: true  # Backend-like validation
      framework: "vitest"
    checkpoints:
      enabled: false
    verification:
      run_tests: true
      run_lint: true
```

### Orchestrated (Complexity 4)

```yaml
input: "Add user authentication with Google OAuth"
complexity: 4

strategy:
  mode: "ORCHESTRATED"
  phases:
    - id: 1
      name: "Setup"
      description: "Dependencies, NextAuth config"
      estimated_tokens: 4000

    - id: 2
      name: "Auth Provider"
      description: "Google OAuth provider, callbacks"
      estimated_tokens: 8000

    - id: 3
      name: "Session Management"
      description: "useSession hook, middleware"
      estimated_tokens: 6000

    - id: 4
      name: "UI Components"
      description: "Login button, user menu"
      estimated_tokens: 5000

  estimated_tokens: 35000
  handoff_likely: false

  config:
    tdd:
      enabled: true
      framework: "vitest"
      coverage_threshold: 80
    checkpoints:
      enabled: true
      frequency: "per_phase"
    verification:
      run_tests: true
      run_lint: true
      run_typecheck: true
      run_build: true
```

## Mode Switching

When complexity increases during execution:

```python
def handle_mode_switch(execution: Execution) -> Strategy:
    """Switch from DIRECT to ORCHESTRATED mid-execution."""

    # Create emergency checkpoint
    checkpoint = CheckpointManager.create(
        execution,
        reason="mode_switch"
    )

    # Analyze remaining work
    remaining = analyze_remaining_work(execution)

    # Create orchestrated strategy for remaining work
    new_intent = execution.intent.copy()
    new_intent.classification.complexity = remaining.new_complexity

    orchestrated = OrchestratedStrategy(new_intent)

    # Mark what's already done
    orchestrated.completed_phases = [{
        "name": "Initial (Direct mode)",
        "files": execution.files_modified
    }]

    output(f"→ Prebacujem na ORCHESTRATED mode ({len(orchestrated.phases)} faza)")

    return orchestrated
```

## Plan Approval Gate

### CRITICAL: User Approval Required for ORCHESTRATED

Before execution begins, ORCHESTRATED strategy MUST obtain user approval.

```python
def request_plan_approval(strategy: OrchestratedStrategy) -> ApprovalResult:
    """Request user approval before ORCHESTRATED execution."""

    # 1. Generate plan summary
    plan_summary = generate_plan_summary(strategy)

    # 2. Write full plan to file
    plan_path = write_plan_file(strategy)

    # 3. Display summary to user
    output(f"""
Plan spreman za: {strategy.intent.summary}
Mode: ORCHESTRATED ({len(strategy.phases)} faza)
Estimated: {strategy._estimate_tokens()} tokena

Faze:
{format_phases(strategy.phases)}

Plan file: {plan_path}
    """)

    # 4. MANDATORY: Ask for approval using AskUserQuestion
    #    DO NOT auto-proceed. DO NOT skip.
    approval = ask_user_question(
        question="Želiš li nastaviti s implementacijom?",
        options=[
            {"label": "Nastavi", "description": "Pokreni implementaciju prema planu"},
            {"label": "Pregledaj plan", "description": "Prikaži detaljan plan prije odluke"},
            {"label": "Odustani", "description": "Prekini bez implementacije"}
        ]
    )

    if approval == "Nastavi":
        return ApprovalResult(approved=True)
    elif approval == "Pregledaj plan":
        # Show full plan, ask again
        show_full_plan(plan_path)
        return request_plan_approval(strategy)  # Recursive
    else:
        return ApprovalResult(approved=False, reason="User cancelled")


def generate_plan_summary(strategy: OrchestratedStrategy) -> str:
    """Generate concise plan summary for user review."""

    lines = []
    for phase in strategy.phases:
        files_str = ", ".join(phase.files[:3]) if phase.files else "TBD"
        if len(phase.files) > 3:
            files_str += f" (+{len(phase.files) - 3} more)"
        lines.append(f"  {phase.id}. {phase.name}: {phase.description}")
        lines.append(f"     Files: {files_str}")

    return "\n".join(lines)


def write_plan_file(strategy: OrchestratedStrategy) -> str:
    """Write detailed plan to .claude/plans/ directory."""

    import datetime
    session_id = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    plan_path = f".claude/plans/auto-{session_id}.md"

    plan_content = f"""# Execution Plan

## Task
{strategy.intent.original_input}

## Classification
- Intent: {strategy.intent.classification.intent_type}
- Complexity: {strategy.intent.classification.complexity}/5
- Work Type: {strategy.intent.classification.work_type}

## Strategy
- Mode: ORCHESTRATED
- Phases: {len(strategy.phases)}
- Estimated Tokens: {strategy._estimate_tokens()}
- Handoff Likely: {strategy._is_handoff_likely()}

## Phases

{format_phases_detailed(strategy.phases)}

## Verification Plan

After each phase:
- Run tests
- Check lint
- Verify types

Final verification:
- Full test suite
- Build check
- Integration tests

## TDD Configuration
- Framework: {strategy.config.tdd.framework}
- Coverage Threshold: {strategy.config.tdd.coverage_threshold}%

---
Generated: {datetime.datetime.now().isoformat()}
"""

    # Write to file
    write_file(plan_path, plan_content)
    return plan_path
```

### Approval Flow

```
Strategy Selected (ORCHESTRATED)
         │
         ▼
   Write Plan File
         │
         ▼
   Display Summary
         │
         ▼
┌─────────────────────────────────────┐
│  AskUserQuestion:                   │
│  "Želiš li nastaviti?"              │
│                                     │
│  [Nastavi] [Pregledaj] [Odustani]   │
└─────────────────────────────────────┘
         │
    ┌────┴────┐
    │         │
 Nastavi   Odustani
    │         │
    ▼         ▼
 Execute    Exit
```

### IMPORTANT

- **NEVER** auto-proceed to execution without explicit user approval
- **ALWAYS** use AskUserQuestion tool for approval
- **ALWAYS** provide "Odustani" option
- Plan file MUST be written before asking for approval
- For DIRECT strategy, approval is NOT required (simple tasks)

## Integration

### With Resolver

Receives resolved intent with confirmation to proceed.

### With Executors

Passes strategy to appropriate executor:
- DirectStrategy → DirectExecutor (no approval needed)
- OrchestratedStrategy → OrchestratedExecutor (AFTER approval)

### With Memory

Stores strategy decisions for:
- Learning optimal decomposition
- Improving token estimates
- Better handoff prediction
