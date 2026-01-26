# Intent Classifier

Classifies enriched intent by type, complexity (1-5), and work type.

## When to Use

- After Enricher produces EnrichedIntent
- Before Resolver checks for ambiguity

## What It Does

```
Enriched Intent
      │
      ▼
┌─────────────────────────────────────────────┐
│              CLASSIFIER                      │
├─────────────────────────────────────────────┤
│                                             │
│  1. Classify Intent Type                    │
│     → FEATURE, BUG_FIX, REFACTOR...         │
│                                             │
│  2. Score Complexity (1-5)                  │
│     → Heuristic → Hybrid → ML               │
│                                             │
│  3. Detect Work Type                        │
│     → FRONTEND, BACKEND, FULLSTACK...       │
│                                             │
│  4. Record Prediction                       │
│     → For later feedback loop               │
│                                             │
└─────────────────────────────────────────────┘
      │
      ▼
Classified Intent
```

## Intent Types

```typescript
type IntentType =
  | "FEATURE"       // New functionality
  | "BUG_FIX"       // Bug fix
  | "REFACTOR"      // Refactoring without behavior change
  | "RESEARCH"      // Investigation, exploration
  | "QUESTION"      // Simple question (no code needed)
  | "MAINTENANCE"   // Dependency updates, cleanup
  | "DOCUMENTATION" // Docs, comments
  | "DELETION";     // Remove code/files
```

### Type Detection

```python
def classify_type(intent: EnrichedIntent) -> IntentType:
    """Classify intent type from signals."""

    # Check primary signal from parser
    signal = intent.intent_signals[0] if intent.intent_signals else None

    if signal:
        TYPE_MAP = {
            "ADD": "FEATURE",
            "CREATE": "FEATURE",
            "IMPLEMENT": "FEATURE",
            "FIX": "BUG_FIX",
            "DEBUG": "BUG_FIX",
            "REPAIR": "BUG_FIX",
            "REFACTOR": "REFACTOR",
            "CLEAN": "REFACTOR",
            "REORGANIZE": "REFACTOR",
            "INVESTIGATE": "RESEARCH",
            "EXPLORE": "RESEARCH",
            "UNDERSTAND": "RESEARCH",
            "UPDATE_DEPS": "MAINTENANCE",
            "CLEANUP": "MAINTENANCE",
            "DELETE": "DELETION",
            "REMOVE": "DELETION",
        }

        if signal.type in TYPE_MAP:
            return TYPE_MAP[signal.type]

    # Keyword-based fallback
    keywords = detect_keywords(intent.raw_input)

    if any(kw in keywords for kw in ["add", "create", "new", "implement"]):
        return "FEATURE"
    if any(kw in keywords for kw in ["fix", "bug", "broken", "error"]):
        return "BUG_FIX"
    if any(kw in keywords for kw in ["?", "what", "how", "why", "explain"]):
        if needs_code_change(intent):
            return "RESEARCH"
        return "QUESTION"

    # Default to FEATURE for action-oriented requests
    return "FEATURE"
```

## Complexity Scoring

### The Three Phases

| Phase | When | Method | Accuracy |
|-------|------|--------|----------|
| Cold Start | 0-20 tasks | Pure heuristics | ~60% |
| Hybrid | 20-50 tasks | Heuristics + embeddings | ~75% |
| Full ML | 50+ tasks | Trained model | ~85% |

### Phase 1: Heuristic (Cold Start)

```python
def heuristic_complexity(intent: EnrichedIntent) -> int:
    """Heuristic scoring for cold start."""

    score = 1

    # File count estimation
    estimated_files = estimate_files(intent)
    if estimated_files > 10:
        score += 2
    elif estimated_files > 5:
        score += 1

    # Keyword signals
    COMPLEX_KEYWORDS = [
        "auth", "authentication", "authorization",
        "payment", "billing", "subscription",
        "migration", "migrate", "upgrade",
        "refactor entire", "rewrite", "overhaul",
        "api", "integration", "sync"
    ]

    input_lower = intent.raw_input.lower()
    for keyword in COMPLEX_KEYWORDS:
        if keyword in input_lower:
            score += 1
            break  # Only count once

    # Sub-task count
    if len(intent.sub_tasks) > 3:
        score += 2
    elif len(intent.sub_tasks) > 1:
        score += 1

    # New dependencies needed
    if needs_new_dependencies(intent):
        score += 1

    # Multi-component work
    if involves_multiple_components(intent):
        score += 1

    return min(score, 5)


def estimate_files(intent: EnrichedIntent) -> int:
    """Estimate files that will be touched."""

    # Base on references
    referenced_files = len(intent.references)

    # Check for patterns
    if "component" in intent.raw_input.lower():
        # Component = main + test + possibly style
        return max(referenced_files, 3)

    if "api" in intent.raw_input.lower():
        # API = route + handler + types + test
        return max(referenced_files, 4)

    # Default minimum
    return max(referenced_files, 1)
```

### Phase 2: Hybrid (20-50 tasks)

```python
def hybrid_complexity(intent: EnrichedIntent, memory: Memory) -> int:
    """Heuristics + embeddings for better matching."""

    # Get base heuristic score
    base_score = heuristic_complexity(intent)

    # Find similar past tasks
    similar = memory.find_similar(intent.raw_input, limit=5)

    if not similar:
        return base_score

    # Weight by similarity
    weighted_scores = []
    total_weight = 0

    for task in similar:
        if task.actual_complexity:  # Only if we have feedback
            weight = task.similarity_score
            weighted_scores.append(task.actual_complexity * weight)
            total_weight += weight

    if total_weight > 0:
        learned_score = sum(weighted_scores) / total_weight

        # Blend: 60% learned, 40% heuristic
        return round(0.6 * learned_score + 0.4 * base_score)

    return base_score
```

### Phase 3: Full ML (50+ tasks)

```python
def ml_complexity(intent: EnrichedIntent, model: ComplexityModel) -> int:
    """ML model trained on user's tasks."""

    features = extract_features(intent)
    # Features include:
    # - Embedding of raw_input
    # - Project context embedding
    # - Sub-task count
    # - Estimated file count
    # - Pattern matches
    # - Historical similar task complexities

    prediction = model.predict(features)
    confidence = model.confidence(features)

    if confidence < 0.7:
        # Fall back to hybrid
        return hybrid_complexity(intent, model.memory)

    return round(prediction)
```

### Phase Selection

```python
def score_complexity(intent: EnrichedIntent, memory: Memory) -> int:
    """Select scoring method based on training data."""

    task_count = memory.get_task_count_with_feedback()

    if task_count < 20:
        return heuristic_complexity(intent)
    elif task_count < 50:
        return hybrid_complexity(intent, memory)
    else:
        model = load_complexity_model()
        if model and model.is_trained:
            return ml_complexity(intent, model)
        return hybrid_complexity(intent, memory)
```

## Complexity Rubric

| Score | Files | Duration | Characteristics |
|-------|-------|----------|-----------------|
| 1 | 1-2 | <5 min | Typo fix, simple change, one function |
| 2 | 2-4 | 5-15 min | Small feature, bug fix, add test |
| 3 | 4-8 | 15-45 min | Medium feature, multiple components |
| 4 | 8-15 | 45-120 min | Large feature, new system |
| 5 | 15+ | 2h+ | Architecture change, major refactor |

## Work Type Detection

```python
def detect_work_type(intent: EnrichedIntent) -> WorkType:
    """Determine what kind of work this is."""

    # Check entities from parser
    entities = [e.value.lower() for e in intent.entities]

    # Check for explicit mentions
    if any(e in ["frontend", "ui", "component", "page", "css", "style"] for e in entities):
        if any(e in ["api", "backend", "database", "server"] for e in entities):
            return "FULLSTACK"
        return "FRONTEND"

    if any(e in ["api", "backend", "database", "server", "endpoint"] for e in entities):
        return "BACKEND"

    # Infer from file patterns
    files = intent.references + estimate_file_patterns(intent)

    frontend_patterns = ["*.tsx", "*.jsx", "*.vue", "*.css", "*.scss", "components/*"]
    backend_patterns = ["*.py", "routes/*", "api/*", "models/*", "*.go"]

    has_frontend = any(matches_patterns(f, frontend_patterns) for f in files)
    has_backend = any(matches_patterns(f, backend_patterns) for f in files)

    if has_frontend and has_backend:
        return "FULLSTACK"
    if has_frontend:
        return "FRONTEND"
    if has_backend:
        return "BACKEND"

    # Check project context
    stack = intent.project.stack.lower()

    if "react" in stack or "vue" in stack or "svelte" in stack:
        return "FRONTEND"
    if "django" in stack or "flask" in stack or "express" in stack:
        return "BACKEND"
    if "next" in stack or "nuxt" in stack:
        return "FULLSTACK"

    return "UNKNOWN"
```

## Output Structure

```typescript
interface ClassifiedIntent extends EnrichedIntent {
  // From Enricher plus:

  classification: {
    type: IntentType;
    complexity: 1 | 2 | 3 | 4 | 5;
    work_type: "FRONTEND" | "BACKEND" | "FULLSTACK" | "UNKNOWN";
    execution_mode: "DIRECT" | "ORCHESTRATED";
    use_tdd: boolean;
    estimated_files: number;
  };

  prediction: {
    id: string;            // For feedback tracking
    method: "heuristic" | "hybrid" | "ml";
    confidence: number;
    similar_tasks: string[];  // IDs used for prediction
  };
}
```

## Execution Mode Selection

```python
def select_execution_mode(complexity: int) -> str:
    """Select mode based on complexity."""

    if complexity <= 2:
        return "DIRECT"
    else:
        return "ORCHESTRATED"


def should_use_tdd(complexity: int, work_type: str) -> bool:
    """Determine if TDD should be used."""

    # Always TDD for complexity 3+
    if complexity >= 3:
        return True

    # Skip for config/docs work
    if work_type == "DOCUMENTATION":
        return False

    # Optional for complexity 2 backend
    if complexity == 2 and work_type == "BACKEND":
        return True

    return False
```

## Feedback Loop

```python
def record_prediction(intent: ClassifiedIntent):
    """Record prediction for later feedback."""

    prediction = {
        "id": generate_prediction_id(),
        "task_input": intent.raw_input,
        "predicted_complexity": intent.classification.complexity,
        "predicted_files": intent.classification.estimated_files,
        "method": intent.prediction.method,
        "timestamp": now_iso()
    }

    store_prediction(prediction)
    return prediction["id"]


def provide_feedback(prediction_id: str, actual_data: dict):
    """Record actual results for learning."""

    prediction = get_prediction(prediction_id)

    feedback = {
        "prediction_id": prediction_id,
        "predicted_complexity": prediction["predicted_complexity"],
        "actual_complexity": calculate_actual_complexity(actual_data),
        "predicted_files": prediction["predicted_files"],
        "actual_files": actual_data["files_changed"],
        "success": actual_data["verified"],
        "timestamp": now_iso()
    }

    store_feedback(feedback)

    # Check if retrain needed
    feedback_count = get_feedback_count()
    if feedback_count % 10 == 0 and feedback_count >= 20:
        trigger_model_retrain()
```

## Example Classification

### Input

```yaml
enriched_intent:
  raw_input: "Add user authentication with Google OAuth"
  entities:
    - { type: "feature", value: "authentication" }
    - { type: "technology", value: "Google OAuth" }
  project:
    stack: "Next.js 14, TypeScript, Supabase"
  memory:
    similar_tasks:
      - input: "Implement login with email"
        actual_complexity: 4
        similarity: 0.78
```

### Output

```yaml
classified_intent:
  # ... all from EnrichedIntent ...

  classification:
    type: "FEATURE"
    complexity: 4
    work_type: "FULLSTACK"
    execution_mode: "ORCHESTRATED"
    use_tdd: true
    estimated_files: 8

  prediction:
    id: "pred-20250126-001"
    method: "hybrid"
    confidence: 0.75
    similar_tasks: ["task-2024-12-15-001"]
```

## Integration

### With Enricher

Receives EnrichedIntent with project and memory context.

### With Resolver

ClassifiedIntent feeds into Resolver for:
- Ambiguity detection
- Critical action detection
- User confirmation decisions

### With Memory

Uses memory for:
- Finding similar tasks
- Training ML model
- Recording predictions

## Performance

Target latency: < 200ms for classification

Optimization:
- Pre-compute embeddings for common phrases
- Cache heuristic calculations
- Lazy-load ML model only when needed
