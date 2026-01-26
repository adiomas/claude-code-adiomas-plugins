# Intent Parser

Parses natural language input and extracts structured intent information.

## When to Use

- First step in `/do` command pipeline
- When processing any natural language task request

## What It Does

```
Input: "Ono od jučer s loginima ne radi, popravi i dodaj error handling"
                              │
                              ▼
                      ┌──────────────┐
                      │    PARSER    │
                      └──────────────┘
                              │
                              ▼
Output: {
  tokens: ["ono", "od jučer", "s loginima", "ne radi", "popravi", "i", "dodaj", "error handling"],
  references: [{ type: "temporal", value: "jučer", scope: "login" }],
  entities: ["login", "error handling"],
  intent_signals: ["ne radi" → BUG_FIX, "dodaj" → FEATURE],
  sub_tasks: ["popravi login bug", "dodaj error handling"],
  is_composite: true
}
```

## Parsing Steps

### 1. Tokenization

Split input into meaningful tokens:

```
"Napravi auth i dark mode"
→ ["Napravi", "auth", "i", "dark mode"]
```

### 2. Reference Detection

Find references to past work:

| Pattern | Type | Resolution |
|---------|------|------------|
| "ono" | last_work | Most recent session |
| "od jučer" | temporal | Filter by date |
| "s loginima" | scope | Semantic: "login" |
| "nastavi" | continuation | Incomplete tasks |
| "isto kao" | similarity | Similar past work |

### 3. Entity Extraction

Identify named entities:

- **Files**: `src/auth/login.ts`
- **Features**: `authentication`, `dark mode`
- **Technologies**: `React`, `TypeScript`
- **Components**: `LoginForm`, `ThemeProvider`

### 4. Intent Signal Detection

Keywords that indicate intent type:

```yaml
signals:
  FEATURE:
    - "napravi"
    - "dodaj"
    - "kreiraj"
    - "implementiraj"
    - "add"
    - "create"
    - "implement"

  BUG_FIX:
    - "popravi"
    - "ne radi"
    - "bug"
    - "fix"
    - "broken"
    - "error"

  REFACTOR:
    - "refaktoriraj"
    - "očisti"
    - "reorganiziraj"
    - "refactor"
    - "clean up"

  RESEARCH:
    - "istraži"
    - "zašto"
    - "kako"
    - "understand"
    - "analyze"

  QUESTION:
    - "?"
    - "što je"
    - "objasni"
    - "what is"
    - "explain"
```

### 5. Composite Detection

Detect multi-task requests:

```
Conjunctions: "i", "pa", "zatim", "nakon toga", "and", "then"

"Napravi auth i dark mode"
→ is_composite: true
→ sub_tasks: ["Napravi auth", "Napravi dark mode"]
```

### 6. Dependency Analysis

For composite requests, analyze dependencies:

```python
# Independent (can run parallel)
"Napravi auth i dark mode"
→ dependencies: none

# Dependent (must be sequential)
"Kreiraj User model, zatim dodaj validaciju"
→ task 2 depends on task 1
```

## Reference Resolution Algorithm

```python
def resolve_reference(ref, context, memory):
    """
    Hybrid approach:
    1. Check recent tasks (recency)
    2. If no context match → semantic search
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
    best_match = semantic_search(all_tasks, context)

    if best_match.score > 0.7:
        return ResolvedRef(
            source=best_match.task,
            confidence=best_match.score,
            method="semantic"
        )

    # Step 3: Cannot resolve
    return ResolvedRef(
        source=None,
        needs_clarification=True
    )
```

## Output Structure

```typescript
interface ParsedIntent {
  // Raw input
  raw_input: string;

  // Tokenization
  tokens: string[];

  // References found
  references: Reference[];

  // Entities extracted
  entities: Entity[];

  // Intent signals detected
  intent_signals: IntentSignal[];

  // Primary intent type (best guess)
  primary_intent: IntentType;

  // Sub-tasks if composite
  sub_tasks: SubTask[];
  is_composite: boolean;

  // Parsing confidence
  confidence: number;

  // Issues that need resolution
  needs_resolution: ResolutionNeeded[];
}

interface Reference {
  type: "temporal" | "scope" | "continuation" | "similarity";
  value: string;
  resolved_to?: PastTask;
  confidence: number;
}

interface SubTask {
  id: string;
  description: string;
  dependencies: string[];
  intent_type: IntentType;
}
```

## Examples

### Simple Request

```
Input: "Add login page"

Output: {
  raw_input: "Add login page",
  tokens: ["Add", "login", "page"],
  references: [],
  entities: [{ type: "feature", value: "login page" }],
  intent_signals: [{ keyword: "Add", type: "FEATURE" }],
  primary_intent: "FEATURE",
  sub_tasks: [],
  is_composite: false,
  confidence: 0.95
}
```

### Reference Request

```
Input: "Ono od jučer ne radi"

Output: {
  raw_input: "Ono od jučer ne radi",
  tokens: ["Ono", "od jučer", "ne radi"],
  references: [{
    type: "temporal",
    value: "jučer",
    resolved_to: { id: "session-2025-01-25", task: "Implement OAuth" },
    confidence: 0.92
  }],
  entities: [],
  intent_signals: [{ keyword: "ne radi", type: "BUG_FIX" }],
  primary_intent: "BUG_FIX",
  sub_tasks: [],
  is_composite: false,
  confidence: 0.88
}
```

### Composite Request

```
Input: "Napravi auth i dark mode"

Output: {
  raw_input: "Napravi auth i dark mode",
  tokens: ["Napravi", "auth", "i", "dark mode"],
  references: [],
  entities: [
    { type: "feature", value: "auth" },
    { type: "feature", value: "dark mode" }
  ],
  intent_signals: [{ keyword: "Napravi", type: "FEATURE" }],
  primary_intent: "FEATURE",
  sub_tasks: [
    { id: "sub-1", description: "Napravi auth", dependencies: [] },
    { id: "sub-2", description: "Napravi dark mode", dependencies: [] }
  ],
  is_composite: true,
  confidence: 0.93
}
```

## Integration

### With Enricher

Parser output flows to Enricher:
1. Enricher loads memory context
2. Resolves any unresolved references
3. Adds project context
4. Returns enriched intent

### With Classifier

After enrichment:
1. Classifier determines complexity
2. Assigns work type
3. Finalizes intent type

## Error Handling

### Ambiguous Input

```
Input: "Fix it"

Output: {
  confidence: 0.3,
  needs_resolution: [{
    type: "unclear_reference",
    question: "What should I fix?",
    suggestions: ["recent auth changes", "login bug", "test failures"]
  }]
}
```

### Multiple Interpretations

```
Input: "Make login better"

Output: {
  confidence: 0.5,
  needs_resolution: [{
    type: "ambiguous_intent",
    interpretations: [
      { intent: "FEATURE", description: "Add features to login" },
      { intent: "REFACTOR", description: "Improve login code quality" },
      { intent: "BUG_FIX", description: "Fix login issues" }
    ]
  }]
}
```
