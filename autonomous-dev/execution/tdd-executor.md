# TDD Executor

Executes code with TDD discipline: RED → GREEN → REFACTOR cycle.

## When to Use

- Complexity 3+ tasks (always)
- Complexity 2 backend tasks (optional)
- Any task where user explicitly requests TDD
- When modifying critical code paths

## The TDD Cycle

```
┌─────────────────────────────────────────────────────────────────┐
│                      TDD CYCLE                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────┐     ┌─────────┐     ┌─────────┐                   │
│  │   RED   │ ──▶ │  GREEN  │ ──▶ │REFACTOR │                   │
│  │         │     │         │     │         │                   │
│  │ Write   │     │ Write   │     │ Clean   │                   │
│  │ failing │     │ minimal │     │ up code │                   │
│  │ test    │     │ code    │     │         │                   │
│  └─────────┘     └─────────┘     └─────────┘                   │
│       │                               │                         │
│       │                               │                         │
│       └───────────────────────────────┘                         │
│                (next unit)                                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation

```python
class TDDExecutor:
    """Execute code with TDD discipline."""

    def __init__(self, project: Project):
        self.project = project
        self.test_framework = detect_test_framework(project)
        self.test_runner = get_test_runner(self.test_framework)

    def should_use_tdd(self, complexity: int, file_type: str) -> bool:
        """Determine if TDD should be used."""

        # Always TDD for complexity 3+
        if complexity >= 3:
            return True

        # Skip for config/boilerplate
        SKIP_PATTERNS = [
            "*.config.*",
            "*.json",
            "*.yaml",
            "*.yml",
            "*.md",
            "*.css",
            "*.scss",
            "*.env*",
            "*.d.ts"
        ]

        for pattern in SKIP_PATTERNS:
            if fnmatch(file_type, pattern):
                return False

        # Complexity 2 backend = optional TDD
        if complexity == 2:
            return is_backend_file(file_type)

        return False

    def execute_tdd(self, phase: Phase) -> TDDResult:
        """Execute phase with TDD cycle."""

        results = []

        for unit in phase.units:
            unit_result = self._execute_unit_tdd(unit)

            if not unit_result.success:
                return TDDResult(
                    success=False,
                    failed_at=unit,
                    error=unit_result.error,
                    units=results
                )

            results.append(unit_result)

        return TDDResult(
            success=True,
            units=results
        )
```

## RED Phase

### Write Failing Test

```python
def _red_phase(self, unit: Unit) -> RedResult:
    """Write failing test for unit."""

    output(f"  → RED: Writing tests for {unit.name}...")

    # Generate test file
    test_content = self._generate_test(unit)
    test_file = self._get_test_path(unit)

    # Write test
    write_file(test_file, test_content)

    # Run test - should fail
    run_result = self.test_runner.run(test_file)

    if run_result.all_passed:
        # Test passed without implementation - suspicious
        output(f"  ! Warning: Test passed before implementation")
        return RedResult(
            success=True,
            warning="test_passed_prematurely",
            test_file=test_file
        )

    if run_result.has_syntax_error:
        # Test itself has error
        return RedResult(
            success=False,
            error="Test has syntax error",
            details=run_result.error
        )

    # Expected: test fails
    output(f"  ✗ Test fails (expected)")
    return RedResult(
        success=True,
        test_file=test_file,
        failing_tests=run_result.failed_count
    )
```

### Test Generation

```python
def _generate_test(self, unit: Unit) -> str:
    """Generate test content for unit."""

    # Get project-specific template
    template = self._get_test_template()

    # Extract test cases from unit specification
    test_cases = self._extract_test_cases(unit)

    return template.render(
        unit_name=unit.name,
        unit_path=unit.relative_path,
        test_cases=test_cases,
        imports=self._get_required_imports(unit)
    )


def _extract_test_cases(self, unit: Unit) -> List[TestCase]:
    """Extract test cases from unit behavior spec."""

    cases = []

    # Happy path
    cases.append(TestCase(
        name=f"should {unit.primary_behavior}",
        arrangement=unit.arrangement,
        action=unit.action,
        assertion=unit.expected_result
    ))

    # Edge cases
    for edge in unit.edge_cases:
        cases.append(TestCase(
            name=f"should {edge.description}",
            arrangement=edge.arrangement,
            action=edge.action,
            assertion=edge.expected_result
        ))

    # Error cases
    for error in unit.error_cases:
        cases.append(TestCase(
            name=f"should {error.description}",
            arrangement=error.arrangement,
            action=error.action,
            assertion=f"throw {error.expected_error}"
        ))

    return cases
```

### Test Templates

```python
# Vitest template
VITEST_TEMPLATE = """
import { describe, it, expect, beforeEach } from 'vitest';
import { {{ unit_name }} } from '{{ unit_path }}';
{% for import in imports %}
import { {{ import.names | join(', ') }} } from '{{ import.path }}';
{% endfor %}

describe('{{ unit_name }}', () => {
  {% if setup %}
  beforeEach(() => {
    {{ setup }}
  });
  {% endif %}

  {% for test in test_cases %}
  it('{{ test.name }}', {% if test.async %}async {% endif %}() => {
    // Arrange
    {{ test.arrangement }}

    // Act
    {% if test.async %}
    const result = await {{ test.action }};
    {% else %}
    const result = {{ test.action }};
    {% endif %}

    // Assert
    expect(result).{{ test.assertion }};
  });

  {% endfor %}
});
"""

# Jest template
JEST_TEMPLATE = """
import { {{ unit_name }} } from '{{ unit_path }}';
{% for import in imports %}
import { {{ import.names | join(', ') }} } from '{{ import.path }}';
{% endfor %}

describe('{{ unit_name }}', () => {
  {% for test in test_cases %}
  test('{{ test.name }}', {% if test.async %}async {% endif %}() => {
    {{ test.arrangement }}
    {% if test.async %}
    const result = await {{ test.action }};
    {% else %}
    const result = {{ test.action }};
    {% endif %}
    expect(result).{{ test.assertion }};
  });
  {% endfor %}
});
"""

# Python pytest template
PYTEST_TEMPLATE = """
import pytest
from {{ unit_path }} import {{ unit_name }}
{% for import in imports %}
from {{ import.path }} import {{ import.names | join(', ') }}
{% endfor %}

class Test{{ unit_name | capitalize }}:
    {% for test in test_cases %}
    def test_{{ test.name | snake_case }}(self):
        # Arrange
        {{ test.arrangement }}

        # Act
        result = {{ test.action }}

        # Assert
        assert {{ test.assertion }}
    {% endfor %}
"""
```

## GREEN Phase

### Minimal Implementation

```python
def _green_phase(self, unit: Unit, test_file: str) -> GreenResult:
    """Write minimal code to make tests pass."""

    output(f"  → GREEN: Implementing {unit.name}...")

    # Generate implementation
    impl_content = self._generate_implementation(unit)
    impl_file = unit.path

    # Write implementation
    write_file(impl_file, impl_content)

    # Run tests - should pass now
    run_result = self.test_runner.run(test_file)

    if run_result.all_passed:
        output(f"  ✓ Tests pass ({run_result.passed_count}/{run_result.total_count})")
        return GreenResult(
            success=True,
            impl_file=impl_file,
            tests_passed=run_result.passed_count
        )

    # Tests still failing - enter fix loop
    output(f"  ✗ Tests failing ({run_result.failed_count}/{run_result.total_count})")
    return self._fix_loop(unit, test_file, run_result)


def _fix_loop(self, unit: Unit, test_file: str, initial_result: TestResult) -> GreenResult:
    """Fix implementation until tests pass."""

    max_fixes = 3
    current_result = initial_result

    for attempt in range(max_fixes):
        output(f"  → Fix attempt {attempt + 1}/{max_fixes}")

        # Analyze failure
        failure_analysis = analyze_test_failure(current_result)

        # Generate fix
        fix = generate_fix(failure_analysis, unit)

        # Apply fix
        apply_fix(fix, unit.path)

        # Re-run tests
        current_result = self.test_runner.run(test_file)

        if current_result.all_passed:
            output(f"  ✓ Fixed! Tests pass")
            return GreenResult(
                success=True,
                impl_file=unit.path,
                tests_passed=current_result.passed_count,
                fix_attempts=attempt + 1
            )

    # Failed to fix
    return GreenResult(
        success=False,
        error="Could not make tests pass after {max_fixes} attempts",
        details=current_result.errors
    )
```

## REFACTOR Phase

### Clean Up

```python
def _refactor_phase(self, unit: Unit, test_file: str) -> RefactorResult:
    """Clean up code while keeping tests green."""

    output(f"  → REFACTOR: Cleaning up...")

    # Save original for rollback
    original_content = read_file(unit.path)

    # Identify refactoring opportunities
    opportunities = identify_refactoring_opportunities(unit.path)

    if not opportunities:
        output(f"  → No refactoring needed")
        return RefactorResult(success=True, changes=[])

    changes = []

    for opp in opportunities:
        # Apply refactoring
        apply_refactoring(opp, unit.path)
        changes.append(opp)

        # Verify tests still pass
        run_result = self.test_runner.run(test_file)

        if not run_result.all_passed:
            # Rollback this refactoring
            output(f"  ! Refactoring broke tests - reverting")
            rollback_refactoring(opp, unit.path)
            changes.pop()

    if changes:
        output(f"  ✓ Refactored: {len(changes)} improvements")

    return RefactorResult(
        success=True,
        changes=changes
    )


def identify_refactoring_opportunities(file_path: str) -> List[Refactoring]:
    """Identify safe refactoring opportunities."""

    opportunities = []
    content = read_file(file_path)

    # Extract long functions
    long_functions = find_long_functions(content, threshold=20)
    for func in long_functions:
        opportunities.append(Refactoring(
            type="extract_function",
            target=func,
            description=f"Extract {func.name} into smaller functions"
        ))

    # Find duplicated code
    duplicates = find_duplicates(content)
    for dup in duplicates:
        opportunities.append(Refactoring(
            type="extract_common",
            target=dup,
            description=f"Extract common code into shared function"
        ))

    # Find unclear names
    unclear = find_unclear_names(content)
    for name in unclear:
        opportunities.append(Refactoring(
            type="rename",
            target=name,
            description=f"Rename {name.current} to {name.suggested}"
        ))

    return opportunities
```

## Full Unit Execution

```python
def _execute_unit_tdd(self, unit: Unit) -> UnitResult:
    """Execute full TDD cycle for one unit."""

    # RED
    red_result = self._red_phase(unit)
    if not red_result.success:
        return UnitResult(
            success=False,
            phase="red",
            error=red_result.error
        )

    # GREEN
    green_result = self._green_phase(unit, red_result.test_file)
    if not green_result.success:
        return UnitResult(
            success=False,
            phase="green",
            error=green_result.error
        )

    # REFACTOR
    refactor_result = self._refactor_phase(unit, red_result.test_file)
    # Refactor failures are warnings, not failures

    # Final verification
    final_result = self.test_runner.run(red_result.test_file)

    return UnitResult(
        success=final_result.all_passed,
        test_file=red_result.test_file,
        impl_file=green_result.impl_file,
        tests_passed=final_result.passed_count,
        refactorings=refactor_result.changes
    )
```

## Output Examples

### Successful TDD Cycle

```
→ Faza 2/4: useSession Hook
  → RED: Writing tests for useSession...
  ✗ Test fails (expected)

  → GREEN: Implementing useSession...
  ✓ Tests pass (4/4)

  → REFACTOR: Cleaning up...
  ✓ Refactored: 2 improvements

  ✓ useSession Hook complete
```

### With Fix Loop

```
→ Faza 3/4: AuthMiddleware
  → RED: Writing tests for AuthMiddleware...
  ✗ Test fails (expected)

  → GREEN: Implementing AuthMiddleware...
  ✗ Tests failing (2/5)

  → Fix attempt 1/3
  → Fix attempt 2/3
  ✓ Fixed! Tests pass

  → REFACTOR: Cleaning up...
  → No refactoring needed

  ✓ AuthMiddleware complete
```

### With Refactor Rollback

```
→ Faza 4/4: TokenRefresh
  → RED: Writing tests for TokenRefresh...
  ✗ Test fails (expected)

  → GREEN: Implementing TokenRefresh...
  ✓ Tests pass (6/6)

  → REFACTOR: Cleaning up...
  ! Refactoring broke tests - reverting
  ✓ Refactored: 1 improvement

  ✓ TokenRefresh complete
```

## Integration

### With Orchestrated Executor

Orchestrated mode calls TDD executor for each phase:

```python
def _execute_phase_tdd(self, phase: Phase) -> PhaseResult:
    """Execute phase with TDD."""

    tdd = TDDExecutor(self.project)
    return tdd.execute_tdd(phase)
```

### With Direct Executor

Direct mode uses TDD only when appropriate:

```python
def execute(self):
    tdd = TDDExecutor(self.project)

    if tdd.should_use_tdd(self.intent.complexity, self.file_type):
        return tdd.execute_tdd(self.as_phase())
    else:
        return self._direct_implement()
```

### With Failure Handler

TDD failures escalate to failure handler:

```python
if not green_result.success:
    return failure_handler.handle(
        Failure(
            phase="green",
            error=green_result.error,
            context=unit
        ),
        execution
    )
```

## Configuration

```yaml
# .claude/config.yaml

tdd:
  # When to use TDD
  complexity_threshold: 3  # Always TDD for >= 3
  optional_for_complexity_2: true

  # Skip patterns
  skip_patterns:
    - "*.config.*"
    - "*.json"
    - "*.md"

  # Test framework detection
  frameworks:
    - name: vitest
      detect: ["vitest.config", "vite.config"]
    - name: jest
      detect: ["jest.config", "package.json:jest"]
    - name: pytest
      detect: ["pytest.ini", "pyproject.toml:pytest"]

  # Refactoring
  refactoring:
    enabled: true
    max_function_lines: 20
    check_duplicates: true
    suggest_renames: false  # Can be noisy

  # Fix loop
  max_fix_attempts: 3
```
