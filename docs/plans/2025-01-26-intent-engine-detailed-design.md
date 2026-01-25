# Intent Engine - Detailed Design

**Parent:** AGI-Like Interface Design
**Status:** Approved
**Date:** 2025-01-26

## Overview

Intent Engine je "mozak" AGI-like sustava. Prima prirodni jezik i proizvodi strukturirani intent s execution strategijom.

```
Input: "Ono od jučer ne radi, popravi i dodaj error handling"
                              │
                              ▼
                      ┌──────────────┐
                      │ INTENT ENGINE │
                      └──────────────┘
                              │
                              ▼
Output: {
  type: "BUG_FIX",
  references: ["session-2025-01-25-auth"],
  sub_tasks: ["fix-bug", "add-error-handling"],
  complexity: 3,
  strategy: "ORCHESTRATED",
  critical_actions: false
}
```

---

## 1. Parser Component

### Responsibilities
- Tokenizacija prirodnog jezika
- Ekstrakcija entiteta (fileovi, features, references)
- Detekcija intent tipa
- Razlaganje kompozitnih zahtjeva

### Supported Input Categories

| Kategorija | Pattern | Primjer |
|------------|---------|---------|
| Direktni | `<action> <target>` | "Napravi login stranicu" |
| Reference | `<ref> <context>` | "Ono od jučer", "nastavi" |
| Nejasni | `<vague> <hint>` | "Ne radi", "popravi to" |
| Kompozitni | `<task1> i/pa/zatim <task2>` | "Napravi auth i dark mode" |

### Reference Resolution Algorithm

```python
def resolve_reference(ref: str, context: str, memory: Memory) -> ResolvedRef:
    """
    Hibridni pristup:
    1. Provjeri zadnje taskove (recency)
    2. Ako ne odgovara kontekstu → semantička pretraga
    """

    # Step 1: Recency check
    recent_tasks = memory.get_recent(limit=5)

    for task in recent_tasks:
        if context_matches(task, context):
            return ResolvedRef(
                source=task,
                confidence=0.9,
                method="recency"
            )

    # Step 2: Semantic search
    all_tasks = memory.get_all()
    embeddings = get_embeddings(context)

    best_match = semantic_search(all_tasks, embeddings)

    if best_match.score > 0.7:
        return ResolvedRef(
            source=best_match.task,
            confidence=best_match.score,
            method="semantic"
        )

    # Step 3: Cannot resolve
    return ResolvedRef(
        source=None,
        confidence=0.0,
        method="unresolved",
        needs_clarification=True
    )
```

### Reference Patterns

| Pattern | Meaning | Resolution |
|---------|---------|------------|
| "ono" | Zadnja stvar | recent_tasks[0] |
| "ono od jučer" | Jučerašnji rad | filter by date |
| "ono s loginima" | Rad vezan uz login | semantic: "login" |
| "nastavi" | Nedovršeni task | filter status=incomplete |
| "isto kao prije" | Ponoviti pristup | copy from similar task |

### Composite Request Handling

```python
def parse_composite(input: str) -> List[SubTask]:
    """
    Pametna analiza ovisnosti:
    - Ako neovisni → parallel
    - Ako ovise → sequential
    """

    # Detect split points
    splits = detect_conjunctions(input)  # "i", "pa", "zatim", "nakon toga"

    if not splits:
        return [SingleTask(input)]

    sub_tasks = split_by_conjunctions(input, splits)

    # Analyze dependencies
    for i, task in enumerate(sub_tasks):
        for j, other in enumerate(sub_tasks):
            if i != j and has_dependency(task, other):
                task.depends_on.append(other.id)

    # Determine execution order
    if all(len(t.depends_on) == 0 for t in sub_tasks):
        return ParallelGroup(sub_tasks)
    else:
        return SequentialGroup(topological_sort(sub_tasks))
```

### Dependency Detection Rules

```yaml
dependency_rules:
  # Task B ovisi o Task A ako:

  - rule: "shared_file"
    description: "B modificira file koji A kreira"
    example:
      A: "Kreiraj User model"
      B: "Dodaj validaciju na User"
    result: B depends on A

  - rule: "import_chain"
    description: "B importa nešto što A exporta"
    example:
      A: "Kreiraj useAuth hook"
      B: "Koristi useAuth u Login komponenti"
    result: B depends on A

  - rule: "semantic_order"
    description: "Prirodni redoslijed (auth prije dashboard)"
    example:
      A: "Napravi authentication"
      B: "Napravi admin dashboard"
    result: B likely depends on A

  - rule: "explicit_temporal"
    description: "Eksplicitni temporal marker"
    example: "Napravi X, zatim Y"
    result: Y depends on X
```

---

## 2. Enricher Component

### Responsibilities
- Učitavanje konteksta iz memorije (lokalna + globalna)
- Dodavanje project context-a
- Proširanje intent-a s relevantnim informacijama

### Enrichment Pipeline

```
Raw Intent
    │
    ▼
┌─────────────────────────────────────────────┐
│              ENRICHER                        │
├─────────────────────────────────────────────┤
│                                             │
│  1. Load Project Context                    │
│     → stack, test_cmd, quirks               │
│                                             │
│  2. Load Local Memory                       │
│     → recent work, project patterns         │
│                                             │
│  3. Load Global Memory                      │
│     → universal patterns, preferences       │
│                                             │
│  4. Find Similar Past Tasks                 │
│     → approaches that worked                │
│                                             │
│  5. Detect Applicable Patterns              │
│     → "auth" → bcrypt+JWT pattern           │
│                                             │
└─────────────────────────────────────────────┘
    │
    ▼
Enriched Intent
```

### Enriched Intent Structure

```typescript
interface EnrichedIntent {
  // From Parser
  raw_input: string;
  type: IntentType;
  sub_tasks: SubTask[];

  // From Enricher
  project: {
    stack: string;
    test_cmd: string;
    build_cmd: string;
    quirks: string[];
  };

  memory: {
    similar_tasks: PastTask[];
    applicable_patterns: Pattern[];
    known_gotchas: string[];
  };

  suggestions: {
    approach: string;
    confidence: number;
    source: "local" | "global" | "inferred";
  }[];
}
```

---

## 3. Classifier Component

### Responsibilities
- Određivanje intent tipa (FEATURE, BUG_FIX, etc.)
- Complexity scoring (1-5)
- Work type classification (FRONTEND, BACKEND, FULLSTACK)

### Intent Types

```typescript
type IntentType =
  | "FEATURE"      // Nova funkcionalnost
  | "BUG_FIX"      // Popravak buga
  | "REFACTOR"     // Refaktoriranje bez promjene ponašanja
  | "RESEARCH"     // Istraživanje, pitanja
  | "QUESTION"     // Jednostavno pitanje (ne treba kod)
  | "MAINTENANCE"  // Dependency updates, cleanup
  | "DOCUMENTATION"; // Docs, comments
```

### ML-Based Complexity Scoring

#### Phase 1: Cold Start (0-20 tasks)
```python
def heuristic_complexity(intent: EnrichedIntent) -> int:
    """Heuristička procjena za cold start."""

    score = 1

    # File count estimation
    estimated_files = estimate_files(intent)
    if estimated_files > 10: score += 2
    elif estimated_files > 5: score += 1

    # Keyword signals
    complex_keywords = ["auth", "payment", "migration", "refactor entire"]
    if any(kw in intent.raw_input.lower() for kw in complex_keywords):
        score += 1

    # Sub-task count
    if len(intent.sub_tasks) > 2:
        score += 1

    # New dependencies needed
    if needs_new_dependencies(intent):
        score += 1

    return min(score, 5)
```

#### Phase 2: Hybrid (20-50 tasks)
```python
def hybrid_complexity(intent: EnrichedIntent, memory: Memory) -> int:
    """Heuristika + embeddings za bolje matchanje."""

    # Get base heuristic score
    base_score = heuristic_complexity(intent)

    # Find similar past tasks
    similar = memory.find_similar(intent, limit=5)

    if similar:
        # Weight by similarity
        weighted_scores = [
            task.actual_complexity * task.similarity_score
            for task in similar
        ]
        learned_score = sum(weighted_scores) / sum(t.similarity_score for t in similar)

        # Blend: 60% learned, 40% heuristic
        return round(0.6 * learned_score + 0.4 * base_score)

    return base_score
```

#### Phase 3: Full ML (50+ tasks)
```python
def ml_complexity(intent: EnrichedIntent, model: ComplexityModel) -> int:
    """Pravi ML model treniran na korisnikovim taskovima."""

    features = extract_features(intent)
    # - embedding of raw_input
    # - project context embedding
    # - sub_task count
    # - estimated file count
    # - pattern matches
    # - historical similar task complexities

    prediction = model.predict(features)
    confidence = model.confidence(features)

    if confidence < 0.7:
        # Fall back to hybrid
        return hybrid_complexity(intent, model.memory)

    return round(prediction)
```

### Complexity Rubric

| Score | Files | Duration | Characteristics |
|-------|-------|----------|-----------------|
| 1 | 1-2 | <5 min | Typo fix, simple change, one function |
| 2 | 2-4 | 5-15 min | Small feature, bug fix, add test |
| 3 | 4-8 | 15-45 min | Medium feature, multiple components |
| 4 | 8-15 | 45-120 min | Large feature, new system |
| 5 | 15+ | 2h+ | Architecture change, major refactor |

### Feedback Loop for Learning

```python
def record_task_completion(task_id: str, actual_data: dict):
    """Zapisuje stvarne podatke za učenje."""

    task = get_task(task_id)

    feedback = {
        "task_id": task_id,
        "predicted_complexity": task.complexity,
        "actual_complexity": calculate_actual_complexity(actual_data),
        "predicted_files": task.estimated_files,
        "actual_files": actual_data["files_changed"],
        "predicted_duration": task.estimated_duration,
        "actual_duration": actual_data["duration"],
        "success": actual_data["verified"],
    }

    memory.store_feedback(feedback)

    # Retrain if enough new data
    if memory.feedback_count() % 10 == 0:
        retrain_complexity_model()
```

---

## 4. Resolver Component

### Responsibilities
- Rješavanje nejasnoća
- Odluka: autonomno ili pitaj korisnika
- Detekcija kritičnih akcija

### Decision Algorithm

```python
def resolve(intent: EnrichedIntent) -> Resolution:
    """Odluči treba li pitati korisnika ili nastaviti autonomno."""

    # Check for critical actions
    critical = detect_critical_actions(intent)
    if critical:
        return Resolution(
            action="ASK",
            reason="critical_action",
            question=format_critical_question(critical)
        )

    # Check confidence
    if intent.confidence < 0.7:
        interpretations = generate_interpretations(intent)

        if len(interpretations) <= 3:
            return Resolution(
                action="ASK_CHOICE",
                options=interpretations
            )
        else:
            return Resolution(
                action="ASK_OPEN",
                question="Nisam siguran što misliš. Možeš li pojasniti?"
            )

    # Confident and not critical → proceed
    return Resolution(action="PROCEED")
```

### Critical Actions Detection

```python
CRITICAL_PATTERNS = {
    "deletion": {
        "patterns": [r"\bdelete\b", r"\bremove\b", r"\bobriši\b", r"\brm\b"],
        "exceptions": ["node_modules", ".cache", "build/"],
        "severity": "HIGH"
    },
    "security": {
        "patterns": [r"\bauth\b", r"\bpassword\b", r"\btoken\b", r"\bsecret\b", r"\bpermission\b"],
        "context_required": ["change", "modify", "update", "remove"],
        "severity": "HIGH"
    },
    "database": {
        "patterns": [r"\bmigration\b", r"\bschema\b", r"\bdrop\b", r"\balter\b"],
        "severity": "HIGH"
    },
    "api_breaking": {
        "patterns": [r"\brename endpoint\b", r"\bremove parameter\b", r"\bchange response\b"],
        "severity": "MEDIUM"
    },
    "dependencies": {
        "patterns": [r"\bupgrade\b.*\bmajor\b", r"\breplace\b.*\bwith\b"],
        "severity": "MEDIUM"
    }
}

def detect_critical_actions(intent: EnrichedIntent) -> List[CriticalAction]:
    """Detektira sve kritične akcije u intentu."""

    critical = []
    text = intent.raw_input.lower()

    for category, config in CRITICAL_PATTERNS.items():
        for pattern in config["patterns"]:
            if re.search(pattern, text):
                # Check exceptions
                if any(exc in text for exc in config.get("exceptions", [])):
                    continue

                # Check context requirement
                if "context_required" in config:
                    if not any(ctx in text for ctx in config["context_required"]):
                        continue

                critical.append(CriticalAction(
                    category=category,
                    severity=config["severity"],
                    matched=pattern
                ))

    return critical
```

### Question Formatting

```python
def format_critical_question(critical: List[CriticalAction]) -> str:
    """Formatira pitanje za korisnika."""

    if len(critical) == 1:
        c = critical[0]
        return TEMPLATES[c.category].format(
            action=c.matched,
            severity=c.severity
        )

    # Multiple critical actions
    items = "\n".join(f"• {c.category}: {c.matched}" for c in critical)
    return f"""⚠️ KRITIČNE AKCIJE DETEKTIRANE

Ova operacija uključuje:
{items}

Želiš nastaviti? [Da] [Ne] [Pokaži detalje]"""
```

---

## 5. Strategist Component

### Responsibilities
- Odabir execution strategije (DIRECT vs ORCHESTRATED)
- Planiranje faza za ORCHESTRATED
- Procjena resursa (tokens, vrijeme)

### Strategy Selection

```python
def select_strategy(intent: EnrichedIntent) -> Strategy:
    """Odaberi optimalnu strategiju izvršavanja."""

    complexity = intent.complexity

    if complexity <= 2:
        return DirectStrategy(intent)
    else:
        return OrchestratedStrategy(intent)
```

### Direct Strategy

```python
class DirectStrategy:
    """Za complexity 1-2: jednostavan loop."""

    def __init__(self, intent: EnrichedIntent):
        self.intent = intent
        self.checkpoints = False  # Nije potrebno
        self.parallel = False

    def execute(self):
        return """
        1. Razumij task
        2. Implementiraj (TDD ako ima testove)
        3. Verificiraj
        4. Gotovo
        """
```

### Orchestrated Strategy

```python
class OrchestratedStrategy:
    """Za complexity 3-5: faze s checkpoint-ima."""

    def __init__(self, intent: EnrichedIntent):
        self.intent = intent
        self.phases = self._decompose()
        self.checkpoints = True
        self.parallel = self._can_parallelize()

    def _decompose(self) -> List[Phase]:
        """Razloži u 2-5 faza."""

        if self.intent.sub_tasks:
            # Already decomposed by parser
            return self._tasks_to_phases(self.intent.sub_tasks)

        # Auto-decompose based on complexity
        if self.intent.complexity == 3:
            return self._decompose_medium()
        elif self.intent.complexity == 4:
            return self._decompose_large()
        else:  # 5
            return self._decompose_xlarge()

    def _can_parallelize(self) -> bool:
        """Provjeri mogu li se faze paralelizirati."""

        for phase in self.phases:
            if phase.depends_on:
                return False  # Has dependencies → sequential
        return len(self.phases) >= 2
```

---

## 6. Executor Component

### Responsibilities
- Izvršavanje strategije
- TDD disciplina
- Verifikacija i evidence collection

### Execution Loop

```python
class Executor:
    def execute(self, strategy: Strategy, intent: EnrichedIntent):
        """Glavni execution loop."""

        if isinstance(strategy, DirectStrategy):
            return self._execute_direct(intent)
        else:
            return self._execute_orchestrated(strategy, intent)

    def _execute_direct(self, intent: EnrichedIntent):
        """DIRECT mode: simple loop."""

        # 1. Understand
        plan = self._quick_plan(intent)

        # 2. Implement with TDD
        for file in plan.files:
            if plan.needs_tests:
                self._write_test(file)  # RED
            self._implement(file)        # GREEN
            self._refactor(file)         # REFACTOR

        # 3. Verify
        evidence = self._verify_all()

        # 4. Done
        return Completion(
            success=evidence.all_passed,
            evidence=evidence
        )

    def _execute_orchestrated(self, strategy: OrchestratedStrategy, intent: EnrichedIntent):
        """ORCHESTRATED mode: phases with checkpoints."""

        for phase in strategy.phases:
            # Checkpoint before
            self._checkpoint(phase.id, "starting")

            # Execute phase
            result = self._execute_phase(phase)

            # Verify phase
            evidence = self._verify_phase(phase)

            if not evidence.passed:
                return self._handle_phase_failure(phase, evidence)

            # Checkpoint after
            self._checkpoint(phase.id, "completed", evidence)

        # Final verification
        final_evidence = self._verify_all()

        return Completion(
            success=final_evidence.all_passed,
            evidence=final_evidence,
            phases=strategy.phases
        )
```

### Evidence Collection

```python
class Evidence:
    """Dokaz da je nešto napravljeno."""

    claim: str           # "Kreiran ThemeProvider"
    proof: str           # "npm test → 3/3 passed"
    files_changed: list  # ["src/providers/Theme.tsx"]
    verified_at: str     # ISO timestamp
    verification_cmd: str  # "npm test"
    verification_output: str  # Full output (truncated)

def collect_evidence(phase: Phase) -> Evidence:
    """Prikupi dokaze za fazu."""

    # Run verification
    result = run_verification(phase.verification_cmd)

    return Evidence(
        claim=phase.description,
        proof=f"{phase.verification_cmd} → {result.summary}",
        files_changed=get_changed_files(),
        verified_at=now_iso(),
        verification_cmd=phase.verification_cmd,
        verification_output=truncate(result.output, 500)
    )
```

---

## Integration Example

```
User: "Ono od jučer s loginima ne radi, popravi i dodaj error handling"

┌─────────────────────────────────────────────────────────────────┐
│ PARSER                                                          │
├─────────────────────────────────────────────────────────────────┤
│ Tokens: ["ono", "od jučer", "s loginima", "ne radi",            │
│          "popravi", "i", "dodaj", "error handling"]             │
│                                                                 │
│ Reference: "ono od jučer s loginima" → needs resolution         │
│ Intent signals: "ne radi" → BUG_FIX, "dodaj" → FEATURE          │
│ Composite: "popravi" AND "dodaj error handling"                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ ENRICHER                                                        │
├─────────────────────────────────────────────────────────────────┤
│ Memory search: "login" + "jučer"                                │
│ Found: session-2025-01-25 "Implement Google OAuth login"        │
│ Files: src/auth/login.ts, src/components/LoginForm.tsx          │
│                                                                 │
│ Project: Next.js, Vitest, Supabase                              │
│ Patterns: "error-handling" → try-catch + custom Error classes   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ CLASSIFIER                                                      │
├─────────────────────────────────────────────────────────────────┤
│ Type: BUG_FIX (primary) + FEATURE (secondary)                   │
│ Complexity: 3 (bug in auth + new error handling)                │
│ Work type: FULLSTACK (auth touches frontend + backend)          │
│ Strategy: ORCHESTRATED                                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ RESOLVER                                                        │
├─────────────────────────────────────────────────────────────────┤
│ Reference resolved: session-2025-01-25 (confidence: 0.92)       │
│ Critical actions: NONE                                          │
│ Ambiguity: LOW                                                  │
│ Decision: PROCEED (no questions needed)                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ STRATEGIST                                                      │
├─────────────────────────────────────────────────────────────────┤
│ Strategy: ORCHESTRATED (complexity 3)                           │
│ Phases:                                                         │
│   1. Debug login issue (BUG_FIX)                                │
│   2. Add error handling (FEATURE) - depends on 1               │
│ Parallel: NO (dependency)                                       │
│ Checkpoints: YES                                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ EXECUTOR                                                        │
├─────────────────────────────────────────────────────────────────┤
│ → Debugging login issue...                                      │
│   Found: async/await missing on Supabase call                   │
│   Fix applied: src/auth/login.ts:42                             │
│   Evidence: pnpm test → 5/5 passed ✓                            │
│                                                                 │
│ → Adding error handling...                                      │
│   Created: src/utils/errors.ts (custom Error classes)           │
│   Updated: src/auth/login.ts (try-catch)                        │
│   Evidence: pnpm test → 8/8 passed ✓                            │
│                                                                 │
│ ✓ Gotovo.                                                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## File Locations

```
engine/
├── parser.md           # This component
├── enricher.md         # Memory + context loading
├── classifier.md       # Intent + complexity classification
├── resolver.md         # Ambiguity + critical action handling
├── strategist.md       # Strategy selection
└── executor.md         # Execution + verification
```

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Reference resolution accuracy | >90% | Correct "ono" resolutions |
| Complexity prediction | ±1 score | Predicted vs actual |
| Critical action detection | 100% | No missed destructive actions |
| User questions | <20% of tasks | Tasks needing clarification |
| Execution success | >85% | Tasks completed without failure |
