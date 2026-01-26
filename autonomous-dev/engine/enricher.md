# Intent Enricher

Loads memory context (local + global) and enriches parsed intent with relevant information.

## When to Use

- After Parser produces parsed intent
- Before Classifier determines complexity

## What It Does

```
Parsed Intent
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

## Enrichment Steps

### 1. Load Project Context

From `.claude/memory/project-context.yaml`:

```yaml
project:
  name: "my-saas-app"
  type: "fullstack"

stack:
  language: "typescript"
  framework: "nextjs"
  version: "14"

commands:
  test: "pnpm test"
  build: "pnpm build"
  lint: "pnpm lint"

quirks:
  - "Always await Supabase calls"
  - "CSS modules for styling"
```

### 2. Load Local Memory

From local memory manager:
- Recent sessions (last 7 days)
- Project-specific patterns
- Local learnings

```python
local_context = local_memory.load()

# Resolve unresolved references from parser
for ref in parsed_intent.unresolved_references:
    resolved = local_memory.find_similar(ref.scope)
    if resolved:
        ref.resolved_to = resolved
        ref.confidence = resolved.similarity_score
```

### 3. Load Global Memory

From global memory manager:
- Patterns matching detected domain
- Gotchas for detected technologies
- User preferences

```python
# Detect domain from intent
domains = detect_domains(parsed_intent)  # ["authentication", "api"]

# Load relevant patterns
patterns = []
for domain in domains:
    patterns.extend(global_memory.get_patterns(domain))

# Detect technologies from project
technologies = project_context.stack.values()

# Load relevant gotchas
gotchas = []
for tech in technologies:
    gotchas.extend(global_memory.get_gotchas(tech))
```

### 4. Find Similar Past Tasks

Semantic search for similar past work:

```python
def find_similar_tasks(intent, memory, limit=5):
    """Find past tasks similar to current intent."""

    intent_embedding = get_embedding(intent.raw_input)

    similar = []
    for session in memory.sessions:
        for task in session.tasks:
            task_embedding = get_embedding(task.input)
            similarity = cosine_similarity(intent_embedding, task_embedding)

            if similarity > 0.7:
                similar.append({
                    "task": task,
                    "similarity": similarity,
                    "outcome": task.outcome,
                    "approach": task.decisions
                })

    return sorted(similar, key=lambda x: x["similarity"], reverse=True)[:limit]
```

### 5. Detect Applicable Patterns

Match patterns to current intent:

```python
def detect_applicable_patterns(intent, patterns):
    """Find patterns that apply to this intent."""

    applicable = []

    for pattern in patterns:
        # Check if pattern keywords match intent
        matches = 0
        for keyword in pattern.applicable_when:
            if keyword.lower() in intent.raw_input.lower():
                matches += 1
            if keyword in [e.value for e in intent.entities]:
                matches += 1

        if matches > 0:
            applicable.append({
                "pattern": pattern,
                "match_score": matches / len(pattern.applicable_when),
                "confidence": pattern.confidence
            })

    return sorted(applicable, key=lambda x: x["match_score"], reverse=True)
```

## Output Structure

```typescript
interface EnrichedIntent extends ParsedIntent {
  // Everything from ParsedIntent plus:

  project: {
    name: string;
    stack: string;
    test_cmd: string;
    build_cmd: string;
    lint_cmd: string;
    quirks: string[];
  };

  memory: {
    similar_tasks: SimilarTask[];
    applicable_patterns: ApplicablePattern[];
    known_gotchas: Gotcha[];
    resolved_references: Reference[];
  };

  suggestions: Suggestion[];

  context_tokens: number;  // Tokens used for context
}

interface SimilarTask {
  id: string;
  input: string;
  similarity: number;
  outcome: "success" | "failure";
  approach: string[];
  files: string[];
}

interface ApplicablePattern {
  id: string;
  name: string;
  approach: string;
  match_score: number;
  confidence: number;
}

interface Suggestion {
  approach: string;
  confidence: number;
  source: "similar_task" | "pattern" | "memory";
  evidence: string;
}
```

## Example Enrichment

### Input

```yaml
parsed_intent:
  raw_input: "Add user authentication"
  intent_signals: [{ keyword: "Add", type: "FEATURE" }]
  entities: [{ type: "feature", value: "authentication" }]
  references: []
```

### Output

```yaml
enriched_intent:
  # From ParsedIntent
  raw_input: "Add user authentication"
  primary_intent: "FEATURE"
  entities: [{ type: "feature", value: "authentication" }]

  # Enriched
  project:
    name: "my-saas-app"
    stack: "Next.js 14, TypeScript, Supabase"
    test_cmd: "pnpm test"
    quirks:
      - "Always await Supabase calls"

  memory:
    similar_tasks:
      - id: "session-2024-12-15-task-1"
        input: "Implement Google OAuth"
        similarity: 0.85
        outcome: "success"
        approach: ["NextAuth.js", "JWT in httpOnly cookie"]

    applicable_patterns:
      - id: "auth-password-hashing"
        name: "Password Hashing"
        approach: "bcrypt with cost 12"
        match_score: 0.9
        confidence: 0.95

      - id: "auth-jwt-tokens"
        name: "JWT Token Strategy"
        approach: "Access 15min, refresh 7d, httpOnly"
        match_score: 0.85
        confidence: 0.88

    known_gotchas:
      - tech: "nextjs"
        title: "NEXT_PUBLIC prefix for client vars"
        problem: "Env vars undefined in browser"

  suggestions:
    - approach: "Use NextAuth.js with JWT in httpOnly cookies"
      confidence: 0.87
      source: "similar_task"
      evidence: "Worked in session-2024-12-15"
```

## Conflict Resolution

When local and global memory conflict:

```python
def resolve_conflict(local_knowledge, global_knowledge, context):
    """Use confidence-based resolution."""

    local_score = calculate_effective_confidence(
        local_knowledge,
        context,
        recency_boost=True,
        context_match_boost=True
    )

    global_score = calculate_effective_confidence(
        global_knowledge,
        context,
        frequency_boost=True
    )

    if local_score > global_score:
        return local_knowledge
    else:
        return global_knowledge
```

## Integration

### With Parser

Receives ParsedIntent, adds context.

### With Classifier

EnrichedIntent feeds into Classifier for:
- Better complexity estimation
- More accurate type classification
- Work type detection

### With Memory Managers

Uses:
- `scripts/local-memory.sh load`
- `scripts/global-memory.sh load --domain X --tech Y`

## Performance

Context loading should be fast:
- Use index files for quick lookup
- Cache project context
- Lazy load patterns (only for matched domains)

Target: < 500ms for enrichment step.
