# Failure Handler

Handles execution failures with escalating strategies: Retry → Pivot → Research → Checkpoint/Ask.

## When to Use

- When a phase fails verification
- When tests don't pass after implementation
- When unexpected errors occur during execution
- When complexity increases unexpectedly

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                   FAILURE ESCALATION                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  LEVEL 1: RETRY (up to 3x)                                      │
│  └── Same approach, fix obvious issue                          │
│      │                                                          │
│      ▼ (still failing)                                          │
│                                                                 │
│  LEVEL 2: PIVOT (up to 3x)                                      │
│  └── Try different approach from memory/patterns               │
│      │                                                          │
│      ▼ (still failing)                                          │
│                                                                 │
│  LEVEL 3: RESEARCH (up to 2x)                                   │
│  └── Read more code, understand dependencies                   │
│      │                                                          │
│      ▼ (still failing)                                          │
│                                                                 │
│  LEVEL 4: CHECKPOINT + ASK                                      │
│  └── Save state, ask user for help                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Escalation Levels

| Level | Strategy | Max Attempts | Token Cost | User Interaction |
|-------|----------|--------------|------------|------------------|
| 1 | Retry | 3 | Low | None |
| 2 | Pivot | 3 | Medium | None |
| 3 | Research | 2 | High | None |
| 4 | Checkpoint/Ask | 1 | Low | Required |

## Implementation

```python
class FailureHandler:
    """Handle failures with escalating strategies."""

    def __init__(self):
        self.retry_count = 0
        self.pivot_count = 0
        self.research_count = 0

        self.max_retries = 3
        self.max_pivots = 3
        self.max_research = 2

    def handle(self, failure: Failure, execution: Execution) -> HandlerResult:
        """Handle failure with appropriate strategy."""

        # Classify failure type
        failure_type = classify_failure(failure)

        # Level 1: Retry for simple/transient failures
        if self.retry_count < self.max_retries:
            if failure_type in ["syntax_error", "simple_logic", "test_assertion"]:
                return self._retry(failure, execution)

        # Level 2: Pivot for approach failures
        if self.pivot_count < self.max_pivots:
            if failure_type in ["approach_wrong", "pattern_mismatch", "dependency_issue"]:
                return self._pivot(failure, execution)

        # Level 3: Research for understanding failures
        if self.research_count < self.max_research:
            if failure_type in ["complex_logic", "unknown_api", "integration_issue"]:
                return self._research(failure, execution)

        # Level 4: Give up, ask user
        return self._checkpoint_and_ask(failure, execution)
```

## Level 1: Retry

```python
def _retry(self, failure: Failure, execution: Execution) -> HandlerResult:
    """Retry with targeted fix for the specific error."""

    self.retry_count += 1

    # Analyze error
    error_analysis = analyze_error(failure.error)

    # Apply targeted fix
    if error_analysis.type == "syntax_error":
        fix = generate_syntax_fix(error_analysis)
    elif error_analysis.type == "test_assertion":
        fix = generate_assertion_fix(error_analysis, execution.test_context)
    elif error_analysis.type == "import_error":
        fix = generate_import_fix(error_analysis)
    else:
        fix = generate_generic_fix(error_analysis)

    # Report
    output(f"  → Retry {self.retry_count}/3: {fix.description}")

    return HandlerResult(
        action="RETRY",
        fix=fix,
        phase=execution.current_phase
    )
```

### Retry Analysis Patterns

```python
def analyze_error(error: str) -> ErrorAnalysis:
    """Analyze error to determine fix strategy."""

    patterns = {
        "syntax_error": [
            r"SyntaxError",
            r"Unexpected token",
            r"Parse error"
        ],
        "test_assertion": [
            r"Expected.*but received",
            r"AssertionError",
            r"expect\(.*\)\.to"
        ],
        "import_error": [
            r"Cannot find module",
            r"Module not found",
            r"ImportError"
        ],
        "type_error": [
            r"TypeError",
            r"is not assignable to",
            r"Type.*is not"
        ],
        "runtime_error": [
            r"ReferenceError",
            r"undefined is not",
            r"null is not"
        ]
    }

    for error_type, patterns_list in patterns.items():
        for pattern in patterns_list:
            if re.search(pattern, error):
                return ErrorAnalysis(
                    type=error_type,
                    pattern=pattern,
                    error=error,
                    fix_hint=get_fix_hint(error_type, error)
                )

    return ErrorAnalysis(type="unknown", error=error)
```

## Level 2: Pivot

```python
def _pivot(self, failure: Failure, execution: Execution) -> HandlerResult:
    """Try different approach from memory or patterns."""

    self.pivot_count += 1
    self.retry_count = 0  # Reset retries for new approach

    # Find alternative approaches
    alternatives = find_alternative_approaches(
        execution.intent,
        execution.current_approach,
        failure
    )

    if not alternatives:
        # Force escalate to research
        return self._research(failure, execution)

    # Select best alternative
    alternative = select_best_alternative(alternatives, failure)

    # Report
    output(f"  → Pivot {self.pivot_count}/3: Pokušavam {alternative.name}")

    return HandlerResult(
        action="PIVOT",
        new_approach=alternative,
        phase=execution.current_phase
    )


def find_alternative_approaches(
    intent: ClassifiedIntent,
    current: Approach,
    failure: Failure
) -> List[Approach]:
    """Find alternative approaches from memory and patterns."""

    alternatives = []

    # Check memory for similar tasks that succeeded
    similar_successful = intent.memory.similar_tasks.filter(
        lambda t: t.outcome == "success" and
                  t.approach != current.name
    )

    for task in similar_successful:
        alternatives.append(Approach(
            name=task.approach,
            source="memory",
            confidence=task.similarity * 0.8  # Discount for indirection
        ))

    # Check patterns for alternatives
    for pattern in intent.memory.applicable_patterns:
        if pattern.name != current.name:
            alternatives.append(Approach(
                name=pattern.approach,
                source="pattern",
                confidence=pattern.confidence * 0.7
            ))

    # Generate approaches based on failure type
    if failure.type == "dependency_issue":
        alternatives.append(Approach(
            name="use_alternative_library",
            source="failure_analysis",
            confidence=0.5
        ))

    return sorted(alternatives, key=lambda a: a.confidence, reverse=True)
```

## Level 3: Research

```python
def _research(self, failure: Failure, execution: Execution) -> HandlerResult:
    """Read more code to understand the problem."""

    self.research_count += 1
    self.pivot_count = 0  # Reset pivots after research

    # Determine what to research
    research_targets = determine_research_targets(failure, execution)

    # Research each target
    insights = []
    for target in research_targets:
        if target.type == "file":
            content = read_file(target.path)
            insight = analyze_for_insight(content, failure)
            insights.append(insight)

        elif target.type == "dependency":
            docs = fetch_dependency_docs(target.name)
            insight = extract_relevant_info(docs, failure)
            insights.append(insight)

        elif target.type == "pattern":
            examples = find_pattern_examples(target.pattern)
            insight = synthesize_examples(examples, failure)
            insights.append(insight)

    # Synthesize insights into new approach
    new_approach = synthesize_approach(insights)

    # Report
    output(f"  → Research {self.research_count}/2: Pronašao {len(insights)} uvida")

    return HandlerResult(
        action="RESEARCH",
        insights=insights,
        new_approach=new_approach,
        phase=execution.current_phase
    )


def determine_research_targets(failure: Failure, execution: Execution) -> List[Target]:
    """Determine what to research based on failure."""

    targets = []

    # Always read related files
    related = find_related_files(execution.current_file)
    targets.extend([Target(type="file", path=f) for f in related[:3]])

    # Check imports that might be relevant
    if failure.type in ["import_error", "type_error"]:
        imports = extract_imports(execution.current_file)
        for imp in imports:
            if imp.name in failure.error:
                targets.append(Target(type="file", path=imp.source))

    # Check dependencies
    if failure.type == "dependency_issue":
        dep = extract_dependency_from_error(failure.error)
        if dep:
            targets.append(Target(type="dependency", name=dep))

    # Look for patterns
    if failure.type in ["approach_wrong", "pattern_mismatch"]:
        targets.append(Target(
            type="pattern",
            pattern=execution.current_approach
        ))

    return targets[:5]  # Max 5 research targets
```

## Level 4: Checkpoint and Ask

```python
def _checkpoint_and_ask(self, failure: Failure, execution: Execution) -> HandlerResult:
    """Save state and ask user for help."""

    # Create detailed checkpoint
    checkpoint = create_failure_checkpoint(failure, execution)

    # Generate stuck report
    stuck_report = generate_stuck_report(
        failure=failure,
        attempts={
            "retries": self.max_retries,
            "pivots": self.pivot_count,
            "research": self.research_count
        },
        insights=collect_all_insights()
    )

    # Save report
    save_stuck_report(stuck_report)

    # Format question for user
    question = format_stuck_question(failure, stuck_report)

    # Report
    output(f"""
! Zapeo sam i trebam pomoć.

Pokušao sam:
• {self.max_retries} retry-a
• {self.pivot_count} alternativna pristupa
• {self.research_count} istraživanja

Problem: {failure.summary}

Checkpoint sačuvan: {checkpoint.id}
""")

    return HandlerResult(
        action="ASK",
        checkpoint=checkpoint,
        question=question,
        stuck_report=stuck_report
    )


def format_stuck_question(failure: Failure, report: StuckReport) -> str:
    """Format question for user when stuck."""

    return f"""Zapeo sam na: {failure.summary}

Što sam probao:
{format_attempts(report.attempts)}

Moja analiza:
{report.analysis}

Opcije:
1. Pokaži mi kako ovo napraviti
2. Preskoči ovaj dio za sada
3. Odustani od taska
4. Probaj ponovo s drugačijim pristupom: [opiši]

Što da napravim?"""
```

## Failure Classification

```python
def classify_failure(failure: Failure) -> str:
    """Classify failure to determine handling strategy."""

    # Syntax/parse errors - retry
    if failure.phase == "parse" or "syntax" in failure.error.lower():
        return "syntax_error"

    # Test assertion failures - retry with fix
    if failure.phase == "test" and "expect" in failure.error.lower():
        return "test_assertion"

    # Import/module errors - may need pivot
    if "module" in failure.error.lower() or "import" in failure.error.lower():
        return "dependency_issue"

    # Type errors - retry or pivot
    if "type" in failure.error.lower():
        if failure.retry_count < 2:
            return "simple_logic"
        return "approach_wrong"

    # Multiple failures on same thing - pivot
    if failure.same_location_count >= 2:
        return "approach_wrong"

    # Complex integration - research
    if len(failure.involved_files) > 3:
        return "integration_issue"

    # Unknown API/library - research
    if failure.involves_external_api:
        return "unknown_api"

    return "simple_logic"
```

## Output Examples

### Successful Retry

```
→ Faza 2/4: Session Hook
  → RED: Writing tests...
  → GREEN: Implementing...
  ✗ Test failed: Expected string but received undefined

  → Retry 1/3: Fixing undefined return value
  → GREEN: Re-implementing...
  ✓ Session Hook (4/4 tests)
```

### Successful Pivot

```
→ Faza 3/4: Protected Routes
  → RED: Writing tests...
  → GREEN: Implementing...
  ✗ Middleware not working with App Router

  → Retry 1/3: Adjusting middleware path
  ✗ Still not matching routes

  → Pivot 1/3: Using route groups instead
  → GREEN: Implementing with route groups...
  ✓ Protected Routes (5/5 tests)
```

### Research Success

```
→ Faza 4/4: OAuth Integration
  ✗ Token refresh failing

  → Retry 1/3: Fixing refresh logic
  ✗ Still failing

  → Pivot 1/3: Using auth library built-in refresh
  ✗ Library doesn't support this provider

  → Research 1/2: Reading provider docs...
  → Found: Provider uses non-standard refresh endpoint

  → Implementing custom refresh handler...
  ✓ OAuth Integration (8/8 tests)
```

### Stuck (Needs Help)

```
→ Faza 2/5: Payment Integration
  ✗ Webhook signature verification failing

  → Retry 1/3: Fixing signature computation
  ✗ Still failing

  → Retry 2/3: Using raw body instead
  ✗ Still failing

  → Retry 3/3: Checking encoding
  ✗ Still failing

  → Pivot 1/3: Using provider SDK
  ✗ SDK has same issue

  → Research 1/2: Reading Stripe docs...
  → Research 2/2: Checking Next.js body parsing...

! Zapeo sam i trebam pomoć.

Pokušao sam:
• 3 retry-a
• 1 alternativni pristup
• 2 istraživanja

Problem: Webhook signature nikad ne matchira

Checkpoint sačuvan: chk-20250126-153000

Što da napravim?
```

## Integration

### With Execution Modes

Both Direct and Orchestrated modes use failure handler:
- Direct: Simplified (retry only, then ask)
- Orchestrated: Full escalation

### With Checkpoint Manager

Creates checkpoints at:
- Level 4 (when asking user)
- Before pivots (in case pivot fails)

### With Memory

Records:
- Failed approaches (for future avoidance)
- Successful pivots (for future preference)
- Research insights (for knowledge base)

## Configuration

```yaml
# .claude/config.yaml

failure_handler:
  max_retries: 3
  max_pivots: 3
  max_research: 2

  # Skip directly to ask for certain errors
  skip_to_ask:
    - "EACCES"  # Permission denied
    - "ENOENT"  # File not found (critical path)

  # Auto-answer common stuck scenarios
  auto_resolve:
    - pattern: "node_modules missing"
      action: "run npm install"
```
