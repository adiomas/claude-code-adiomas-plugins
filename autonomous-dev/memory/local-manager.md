# Local Memory Manager

Manages project-specific memory with 90-day retention. Stores project context, session history, and local learnings.

## When to Use

- At session start: load project context
- During task execution: reference past work
- At session end: store learnings
- When resolving references: "ono od jučer"

## Storage Location

```
<project>/.claude/memory/
├── project-context.yaml      # Project-specific context
├── learnings.yaml            # Project learnings
├── references.yaml           # Quick references
└── sessions/
    ├── 2025-01-25.yaml
    └── ...
```

## Operations

### Load Project Context

```bash
# Load all relevant local memory
./scripts/local-memory.sh load

# Output:
# - project-context.yaml
# - Recent sessions (last 7 days)
# - Active learnings
```

### Store Session

```bash
# Store current session results
./scripts/local-memory.sh store-session \
  --task "Implement OAuth" \
  --type FEATURE \
  --files "src/auth/oauth.ts,src/auth/oauth.test.ts" \
  --decisions "decisions.json" \
  --evidence "All tests passed"
```

### Find Similar Work

```bash
# Find past work similar to current intent
./scripts/local-memory.sh find-similar "login authentication"

# Returns:
# - Similar sessions with files, decisions, outcomes
# - Useful for "ono od jučer" references
```

### Store Learning

```bash
# Store a new learning
./scripts/local-memory.sh learn \
  --type quirk \
  --content "CSS modules, not Tailwind directly" \
  --applies-to "src/components/**"
```

### Cleanup Old Data

```bash
# Remove sessions older than 90 days
./scripts/local-memory.sh cleanup
```

## Data Schemas

### Project Context

```yaml
project:
  name: "my-app"
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
  - description: "Always await Supabase calls"
    applies_to: ["src/lib/**"]
```

### Session Entry

```yaml
date: "2025-01-25"
sessions:
  - id: "session-001"
    task:
      input: "Implement OAuth"
      type: FEATURE
      complexity: 4
    outcome:
      status: success
      files_created: [...]
      files_modified: [...]
    decisions: [...]
    learnings: [...]
```

### Learning Entry

```yaml
- id: "learn-001"
  type: quirk  # quirk | pattern | gotcha
  content: "CSS modules for styling"
  applies_to: ["src/components/**"]
  confidence: 0.9
  learned_at: "2025-01-25"
  last_used: "2025-01-26"
  use_count: 3
```

## Retention Policy

| Data Type | Retention | Reason |
|-----------|-----------|--------|
| Project context | Forever | Core project info |
| Sessions | 90 days | Recent work reference |
| Learnings | Until forgotten | May promote to global |
| References | 30 days | Quick lookups |

## Integration with Intent Engine

### Reference Resolution

When Intent Parser sees temporal references:

```
"ono od jučer" → find sessions from yesterday
"login feature" → find sessions mentioning login
"that auth thing" → find auth-related sessions
```

### Enrichment

When Intent Enricher runs:

1. Load project context
2. Load recent sessions (last 7 days)
3. Find similar past work
4. Load applicable quirks
5. Return as memory context

## Conflict with Global Memory

Local memory always wins for:
- Project-specific quirks
- Recent sessions (< 7 days)
- File-specific patterns

Global memory wins for:
- General patterns with high confidence
- Technology-wide gotchas

See `global-manager.md` for conflict resolution details.

## Script Reference

```bash
# Full command reference
./scripts/local-memory.sh --help

# Available commands:
#   load              Load all local memory
#   store-session     Store session results
#   find-similar      Find similar past work
#   learn             Store new learning
#   get-quirks        Get project quirks
#   cleanup           Remove old data
#   export            Export for debugging
```
