# Global Memory Manager

Manages global memory shared across all projects. Stores patterns by domain, gotchas by technology, and user preferences.

## When to Use

- At session start: load relevant patterns/gotchas
- After task success: promote local learnings
- During conflict resolution: compare with local memory
- Periodically: run cleanup/decay

## Storage Location

```
~/.claude/global-memory/
├── index.json                # Quick lookup index
├── patterns/                 # Patterns by domain
│   ├── auth.yaml
│   ├── api.yaml
│   └── ...
├── gotchas/                  # Gotchas by technology
│   ├── react.yaml
│   ├── typescript.yaml
│   └── ...
├── preferences.yaml          # User preferences
├── stats.yaml               # Usage statistics
└── archive/                 # Archived (forgotten) knowledge
```

## Operations

### Load Relevant Knowledge

```bash
# Load knowledge relevant to current context
./scripts/global-memory.sh load \
  --domain "authentication" \
  --tech "react,typescript,supabase"

# Output:
# - Matching patterns
# - Relevant gotchas
# - User preferences
```

### Store Pattern

```bash
# Store a new pattern
./scripts/global-memory.sh store-pattern \
  --domain "auth" \
  --name "JWT Token Strategy" \
  --approach "Access 15min, refresh 7d, httpOnly cookies" \
  --confidence 0.85 \
  --source "my-project"
```

### Store Gotcha

```bash
# Store a new gotcha
./scripts/global-memory.sh store-gotcha \
  --tech "vitest" \
  --title "localStorage Mock" \
  --problem "localStorage undefined in tests" \
  --solution "Use vi.stubGlobal instead of jest.mock"
```

### Update Confidence

```bash
# Increase confidence (success)
./scripts/global-memory.sh update-confidence \
  --id "auth-jwt-tokens" \
  --delta 0.05 \
  --reason "Successful use in new-project"

# Decrease confidence (failure)
./scripts/global-memory.sh update-confidence \
  --id "auth-jwt-tokens" \
  --delta -0.1 \
  --reason "Failed in edge case"
```

### Run Cleanup

```bash
# Run decay and cleanup
./scripts/global-memory.sh cleanup
```

## Data Schemas

### Pattern

```yaml
patterns:
  - id: "auth-password-hashing"
    name: "Password Hashing"
    approach: |
      1. Use bcrypt with cost 12
      2. Never store plain passwords
    code_example: |
      const hash = await bcrypt.hash(password, 12);
    applicable_when:
      - "password"
      - "user registration"
    confidence: 0.95
    learned_from:
      - project: "saas-app"
        date: "2025-01-10"
        success: true
    last_used: "2025-01-25"
    use_count: 12
```

### Gotcha

```yaml
gotchas:
  - id: "vitest-localstorage-mock"
    title: "localStorage Mock"
    problem: "localStorage undefined in tests"
    solution: |
      Use vi.stubGlobal:
      vi.stubGlobal('localStorage', mockStorage);
    wrong_approach: "Using jest.mock('localStorage')"
    confidence: 0.92
    tags: ["testing", "mocking"]
    last_used: "2025-01-25"
```

### Preferences

```yaml
code_style:
  paradigm: "functional-preferred"
  comments: "minimal"
  naming: "descriptive"

testing:
  style: "integration-first"
  coverage_target: 80
  framework_preference: "vitest"

git:
  commit_style: "conventional"
  branch_naming: "feature/kebab-case"
```

## Retention Policy

| Data Type | Retention | Cleanup |
|-----------|-----------|---------|
| Patterns | Forever | Decay to 0.3 threshold |
| Gotchas | Forever | Decay to 0.3 threshold |
| Preferences | Forever | Manual update only |
| Stats | 1 year | Auto-archive |

## Confidence Decay

Knowledge decays when unused:

- **First 30 days**: No decay
- **After 30 days**: 0.5% per day
- **Minimum**: 0.1 (doesn't reach zero from decay)
- **Removal threshold**: 0.3

## Conflict Resolution

When local and global knowledge conflict:

### Calculate Effective Confidence

```
effective = base_confidence
          × recency_factor    (0.8-1.0)
          × frequency_factor  (1.0-1.2)
          × context_factor    (1.0-1.15)
          × success_rate      (0.0-1.0)
```

### Resolution Rules

1. **Local always wins** for:
   - Project-specific quirks
   - Recent sessions (< 7 days)
   - File-specific patterns

2. **Global wins** for:
   - High confidence patterns (> 0.9)
   - Technology-wide gotchas
   - User preferences

3. **Confidence decides** otherwise

## Promotion from Local

Local learnings can be promoted to global when:

1. **Technology-agnostic patterns**: Not specific to project
2. **Common tech gotchas**: React, TypeScript, Node, etc.
3. **User explicitly marks**: `promote_to_global: true`
4. **High success rate**: Used 3+ times successfully

## Script Reference

```bash
# Full command reference
./scripts/global-memory.sh --help

# Available commands:
#   load                  Load relevant global knowledge
#   store-pattern         Store new pattern
#   store-gotcha          Store new gotcha
#   update-confidence     Update knowledge confidence
#   record-usage          Record knowledge was used
#   promote               Promote local learning to global
#   cleanup               Run decay and cleanup
#   stats                 Show usage statistics
#   export                Export for debugging
```

## Integration Points

### With Intent Enricher

1. Detect tech stack from context
2. Load relevant patterns for domain
3. Load gotchas for technologies
4. Return merged memory context

### With Learning Extractor

1. Receive new learning from session
2. Check promotion criteria
3. If promotable, store in global
4. Update index for fast lookup

### With Forgetter

1. Apply time-based decay
2. Process failure penalties
3. Handle user feedback
4. Remove below threshold
