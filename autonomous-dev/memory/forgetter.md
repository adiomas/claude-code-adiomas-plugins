# Forgetter - Memory Cleanup System

Manages knowledge cleanup through time decay, failure penalties, and user feedback.

## Why Forget?

Without forgetting:
- Memory grows unbounded
- Outdated patterns persist
- Wrong learnings accumulate
- Confidence scores become meaningless

## Cleanup Strategies

### 1. Time-Based Decay

Knowledge unused for extended periods loses confidence.

```python
def apply_time_decay(knowledge):
    days_unused = (now() - knowledge.last_used).days

    # No decay for first 30 days
    if days_unused <= 30:
        return knowledge.confidence

    # Gradual decay: 0.5% per day after 30 days
    decay_days = days_unused - 30
    decay_factor = 0.995 ** decay_days

    new_confidence = knowledge.confidence * decay_factor

    # Floor at 0.1 (don't reach zero from decay alone)
    return max(0.1, new_confidence)
```

### 2. Failure-Based Reduction

When knowledge leads to failures, reduce confidence.

```python
def apply_failure_penalty(knowledge, failure):
    # Severity-based penalty
    penalties = {
        "HIGH": 0.15,      # Major failure
        "MEDIUM": 0.10,    # Moderate failure
        "LOW": 0.05        # Minor issue
    }

    penalty = penalties.get(failure.severity, 0.05)
    knowledge.confidence -= penalty
    knowledge.failure_count += 1

    # Add failure note
    knowledge.notes.append({
        "type": "failure",
        "date": now(),
        "context": failure.context,
        "description": failure.description
    })
```

### 3. User Feedback Processing

Handle explicit user corrections.

```python
def process_user_feedback(knowledge, feedback):
    actions = {
        "INCORRECT": lambda: reduce_confidence(knowledge, 0.3),
        "OUTDATED": lambda: mark_for_review(knowledge),
        "FORGET": lambda: archive_knowledge(knowledge),
        "CONFIRM": lambda: boost_confidence(knowledge, 0.1)
    }

    action = actions.get(feedback.type)
    if action:
        action()
```

### 4. Threshold Removal

Remove knowledge below confidence threshold.

```python
REMOVAL_THRESHOLD = 0.3

def remove_low_confidence():
    for knowledge in all_knowledge():
        if knowledge.confidence < REMOVAL_THRESHOLD:
            # Archive, don't delete (can recover)
            archive_knowledge(knowledge)

            log_removal(
                id=knowledge.id,
                final_confidence=knowledge.confidence,
                reason="below_threshold",
                archived_to=f"archive/{knowledge.id}.yaml"
            )
```

## Cleanup Schedule

| Strategy | Frequency | When |
|----------|-----------|------|
| Time decay | Daily | 03:00 (low activity) |
| Failure processing | Immediate | On failure |
| User feedback | Immediate | On feedback |
| Threshold removal | Weekly | Sunday 04:00 |
| Archive cleanup | Monthly | 1st of month |

## Decay Curves

```
Confidence
    1.0 ┤
        │   ╭────────╮
    0.8 ┤───╯        ╰──────────
        │                       ╲
    0.6 ┤                        ╲
        │                         ╲
    0.4 ┤                          ╲
        │ Removal threshold ─────────────
    0.3 ┼─────────────────────────────────
        │                            ╲
    0.1 ┤ Floor ─────────────────────────
        │
    0.0 ┼────────────────────────────────▶
        0    30    60    90    120   150  Days
             │
             └── Decay starts
```

## Archive System

Archived knowledge isn't deleted:

```
~/.claude/global-memory/archive/
├── patterns/
│   ├── auth-old-approach-20250101.yaml
│   └── ...
└── gotchas/
    ├── react-16-issue-20250115.yaml
    └── ...
```

Archive retention: 6 months, then permanent deletion.

## Recovery

Restore archived knowledge if needed:

```bash
./scripts/memory-cleanup.sh restore --id "auth-old-approach-20250101"
```

## Script Usage

```bash
# Run full cleanup cycle
./scripts/memory-cleanup.sh run

# Apply decay only
./scripts/memory-cleanup.sh decay

# Process pending feedback
./scripts/memory-cleanup.sh feedback

# Remove below threshold
./scripts/memory-cleanup.sh prune

# Show cleanup statistics
./scripts/memory-cleanup.sh stats

# Restore from archive
./scripts/memory-cleanup.sh restore --id <id>
```

## Configuration

```yaml
# .claude/memory-config.yaml

cleanup:
  decay_start_days: 30
  decay_rate: 0.005  # 0.5% per day
  min_confidence: 0.1
  removal_threshold: 0.3

  failure_penalties:
    HIGH: 0.15
    MEDIUM: 0.10
    LOW: 0.05

  archive:
    retention_days: 180

  schedule:
    decay: "0 3 * * *"       # Daily at 3am
    prune: "0 4 * * 0"       # Weekly on Sunday
    archive_cleanup: "0 5 1 * *"  # Monthly 1st
```

## Integration Points

### With Learning Extractor

When new learning is stored:
1. Check for duplicates
2. Merge if similar exists
3. Update confidence of existing

### With Memory Managers

Cleanup affects both:
- Local memory (90-day retention)
- Global memory (indefinite, with decay)

### With Execution

After task failure:
1. Identify knowledge that was used
2. Apply failure penalties
3. Record failure context for learning

## Metrics

Track cleanup effectiveness:

```yaml
stats:
  knowledge_count:
    patterns: 45
    gotchas: 32
    total: 77

  cleanup_last_run: "2025-01-26T03:00:00Z"

  removed_this_month:
    by_decay: 3
    by_threshold: 2
    by_feedback: 1
    total: 6

  average_confidence:
    patterns: 0.72
    gotchas: 0.68
    overall: 0.70

  stale_knowledge_percent: 4.2%
```
