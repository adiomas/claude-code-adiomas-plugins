# Learning Extractor

Extracts patterns, gotchas, and decisions from successful tasks to improve future performance.

## When to Use

- After task completes successfully (verified)
- When session ends normally
- When explicitly requested

## Learning Types

| Type | What | Where Stored |
|------|------|--------------|
| Pattern | Approach that worked | Local + maybe Global |
| Gotcha | Problem and solution | Local + maybe Global |
| Decision | Choice made and why | Local only |
| Quirk | Project-specific oddity | Local only |

## Extraction Pipeline

```
Task Completion
      │
      ▼
┌─────────────────┐
│    ANALYZE      │  What happened?
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    EXTRACT      │  Pull out learnings
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    VALIDATE     │  Only from verified success
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│     STORE       │  Local and/or Global
└─────────────────┘
```

## What Gets Extracted

### Patterns

From successful approaches:

```yaml
pattern:
  id: "auth-jwt-httponly"
  domain: "authentication"
  name: "JWT in httpOnly Cookie"
  approach: |
    Store JWT in httpOnly cookie instead of localStorage.
    Prevents XSS access to token.
  code_hint: |
    res.cookie('token', jwt, { httpOnly: true, secure: true });
  applicable_when:
    - "jwt"
    - "authentication"
    - "token storage"
  source_task: "Implement Google OAuth"
  confidence: 0.8
```

### Gotchas

From errors encountered and solved:

```yaml
gotcha:
  id: "supabase-await-required"
  tech: "supabase"
  title: "Always await Supabase calls"
  problem: "Data undefined because async call not awaited"
  solution: "Add await before supabase.from().select()"
  wrong_code: "const data = supabase.from('users').select()"
  correct_code: "const data = await supabase.from('users').select()"
  source_task: "Fix user loading bug"
  confidence: 0.9
```

### Decisions

From choices made during task:

```yaml
decision:
  question: "Token storage location"
  options:
    - "localStorage"
    - "httpOnly cookie"
    - "memory only"
  chosen: "httpOnly cookie"
  reason: "Security - prevents XSS access"
  context: "Authentication for SaaS app"
```

### Quirks

From project-specific discoveries:

```yaml
quirk:
  description: "CSS modules required, not direct Tailwind"
  applies_to: ["src/components/**"]
  discovered_in: "Implement dark mode"
  note: "Project convention, not technical requirement"
```

## Promotion to Global

Criteria for promoting to global memory:

1. **Technology-agnostic patterns**: Not specific to project
2. **Common technology gotchas**: React, TypeScript, Node, etc.
3. **High success rate**: Used 3+ times successfully
4. **User explicitly marks**: `promote_to_global: true`

```python
def should_promote(learning):
    if learning.type == "quirk":
        return False  # Always local

    if learning.type == "decision":
        return False  # Context-specific

    if learning.type == "gotcha":
        COMMON_TECH = ["react", "typescript", "node", "python"]
        return learning.tech in COMMON_TECH

    if learning.type == "pattern":
        return not learning.project_specific

    return False
```

## Validation Requirements

Only extract from verified success:

```python
def can_extract(task):
    # Must have verification evidence
    if not task.verification:
        return False

    # Verification must have passed
    if not task.verification.all_passed:
        return False

    # Pattern must have been applied
    if learning.type == "pattern":
        if not was_applied_successfully(learning):
            return False

    # Gotcha solution must have fixed issue
    if learning.type == "gotcha":
        if not solution_verified(learning):
            return False

    return True
```

## Script Usage

```bash
# Extract learnings from completed task
./scripts/extract-learnings.sh \
  --task-id "task-001" \
  --evidence "All 12 tests passed"

# Extract from current session
./scripts/extract-learnings.sh --session

# Review extracted learnings
./scripts/extract-learnings.sh --review

# Promote a learning to global
./scripts/extract-learnings.sh --promote "learn-001"
```

## Integration Points

### With Session End

At session end, automatically:
1. Analyze completed tasks
2. Extract learnings
3. Store to appropriate memory
4. Update confidence scores

### With /do Command

When task completes:
1. Extract learnings
2. Update patterns used
3. Record decisions made
4. Store gotchas encountered

### With Memory System

Learnings flow to:
- `local-memory.sh learn` for local storage
- `global-memory.sh store-pattern/store-gotcha` for global
