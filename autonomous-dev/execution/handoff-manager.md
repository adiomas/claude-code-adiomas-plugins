# Handoff Manager

Manages session handoff at 80% token usage for seamless multi-session execution.

## When to Use

- Token usage approaching 80% threshold
- Long-running tasks (complexity 4-5)
- Before starting a phase that won't fit in remaining budget
- External orchestrator (claude-agi) is managing sessions

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                   HANDOFF FLOW                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. MONITOR                                                     │
│     └── Track token usage continuously                          │
│                                                                 │
│  2. DETECT                                                      │
│     └── 80% threshold reached                                   │
│                                                                 │
│  3. COMPLETE ATOMIC                                             │
│     └── Finish current atomic operation                         │
│                                                                 │
│  4. CHECKPOINT                                                  │
│     └── Create full handoff checkpoint                          │
│                                                                 │
│  5. SIGNAL                                                      │
│     └── Request handoff from orchestrator                       │
│                                                                 │
│  6. EXIT                                                        │
│     └── Clean exit, orchestrator starts new session             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Token Monitoring

### Budget Tracking

```python
class HandoffManager:
    """Manages session handoff for multi-session tasks."""

    def __init__(self, max_tokens: int = 100000):
        self.max_tokens = max_tokens
        self.handoff_threshold = 0.80  # 80%
        self.warning_threshold = 0.70  # 70%
        self.current_usage = 0

    def update_usage(self, tokens_used: int):
        """Update current token usage."""
        self.current_usage = tokens_used

    def check_status(self) -> TokenStatus:
        """Check current token status."""

        percentage = self.current_usage / self.max_tokens

        if percentage >= self.handoff_threshold:
            return TokenStatus(
                status="HANDOFF_REQUIRED",
                percentage=percentage,
                remaining=self.max_tokens - self.current_usage
            )

        if percentage >= self.warning_threshold:
            return TokenStatus(
                status="WARNING",
                percentage=percentage,
                remaining=self.max_tokens - self.current_usage
            )

        return TokenStatus(
            status="OK",
            percentage=percentage,
            remaining=self.max_tokens - self.current_usage
        )

    def can_fit_phase(self, phase: Phase) -> bool:
        """Check if phase can fit in remaining budget."""

        remaining = self.max_tokens - self.current_usage
        estimated_needed = phase.estimated_tokens

        # Add 20% buffer
        with_buffer = estimated_needed * 1.2

        return remaining >= with_buffer
```

### Why 80%?

```
┌─────────────────────────────────────────────────────────────────┐
│                   TOKEN BUDGET ALLOCATION                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [===== WORK (80%) =====][== HANDOFF (10%) ==][= BUFFER (10%) =]│
│                                                                 │
│  • Work: Actual implementation                                  │
│  • Handoff: Checkpoint creation, context summary                │
│  • Buffer: Unexpected complexity, error handling                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

80% threshold ensures:
- Enough tokens for clean checkpoint
- Room for atomic operation completion
- Buffer for unexpected issues

## Handoff Process

### Step 1: Complete Atomic Operation

```python
def prepare_handoff(self, execution: Execution) -> HandoffPreparation:
    """Prepare for handoff by completing current work."""

    # Identify current atomic operation
    atomic = execution.current_atomic_operation

    if atomic:
        if atomic.can_complete_quickly():
            # Finish it
            result = atomic.complete()
            return HandoffPreparation(
                completed_operation=result,
                status="ready"
            )
        else:
            # Too big - save partial progress
            partial = atomic.save_partial_state()
            return HandoffPreparation(
                partial_state=partial,
                status="partial"
            )

    return HandoffPreparation(status="ready")
```

### Atomic Operations

| Operation | Interruptible? | Action |
|-----------|----------------|--------|
| Writing test | No | Complete test file |
| Implementing function | Yes | Save partial, mark incomplete |
| Running verification | Wait | Wait for result |
| Refactoring | Yes | Rollback to pre-refactor |

### Step 2: Create Checkpoint

```python
def create_handoff_checkpoint(self, execution: Execution) -> Checkpoint:
    """Create comprehensive checkpoint for handoff."""

    # Compress context for next session
    context_summary = compress_for_handoff(execution.context)

    checkpoint = Checkpoint(
        id=generate_checkpoint_id(),
        reason="handoff",
        created_at=now_iso(),

        # Task state
        task_id=execution.task_id,
        task_input=execution.intent.raw_input,
        mode=execution.mode,

        # Progress
        current_phase=execution.current_phase,
        total_phases=len(execution.phases),
        completed_phases=serialize_completed(execution.completed_phases),

        # Decisions (for context)
        decisions=execution.decisions[-10:],  # Last 10

        # Files state
        files_created=execution.files_created,
        files_modified=execution.files_modified,
        git_diff=get_staged_diff(),

        # Context for next session
        context_summary=context_summary,
        tokens_used=self.current_usage,

        # Evidence collected
        evidence=execution.collect_evidence(),

        # Resume instructions
        can_resume=True,
        resume_instructions=generate_resume_instructions(execution)
    )

    save_checkpoint(checkpoint)
    return checkpoint
```

### Context Compression

```python
def compress_for_handoff(context: Context) -> str:
    """Compress context to essential information for next session."""

    summary = f"""
## Task
{context.task_summary}

## Current State
- Phase: {context.current_phase}/{context.total_phases}
- Mode: {context.mode}
- Files touched: {len(context.files_modified)}

## Key Decisions
{format_key_decisions(context.decisions[-5:])}

## Known Gotchas
{format_gotchas(context.relevant_gotchas)}

## Next Steps
{format_next_steps(context.remaining_phases)}

## What Was Working
{format_what_worked(context.completed_phases)}
"""

    return summary.strip()
```

### Step 3: Signal Orchestrator

```python
def signal_handoff(self, checkpoint: Checkpoint):
    """Signal orchestrator to start new session."""

    # Write handoff signal file
    signal = {
        "requested_at": now_iso(),
        "checkpoint_id": checkpoint.id,
        "reason": "token_limit",
        "tokens_used": self.current_usage,
        "tokens_max": self.max_tokens,
        "resume_from": checkpoint.current_phase
    }

    with open(HANDOFF_SIGNAL_PATH, 'w') as f:
        json.dump(signal, f)

    # Also update state
    update_state(
        status="handoff_requested",
        checkpoint_id=checkpoint.id
    )
```

### Step 4: Clean Exit

```python
def execute_handoff(self, execution: Execution) -> HandoffResult:
    """Execute complete handoff process."""

    # 1. Prepare (complete atomic)
    prep = self.prepare_handoff(execution)

    # 2. Create checkpoint
    checkpoint = self.create_handoff_checkpoint(execution)

    # 3. Signal orchestrator
    self.signal_handoff(checkpoint)

    # 4. Output handoff message
    output(f"""
══════════════════════════════════════════════════════════════
 SESSION HANDOFF
══════════════════════════════════════════════════════════════

 Progress: {execution.current_phase}/{len(execution.phases)} phases complete
 Checkpoint: {checkpoint.id}

 Token usage: {self.current_usage:,} / {self.max_tokens:,} ({self.current_usage/self.max_tokens:.0%})

 Resume command:
 claude-agi --continue

 Or manually:
 /auto-execute --continue

══════════════════════════════════════════════════════════════
""")

    return HandoffResult(
        success=True,
        checkpoint=checkpoint,
        message="Handoff complete. Orchestrator will start new session."
    )
```

## Resume Protocol

When next session starts:

```python
def resume_from_handoff(checkpoint_id: str) -> Execution:
    """Resume execution from handoff checkpoint."""

    # 1. Load checkpoint
    checkpoint = load_checkpoint(checkpoint_id)

    # 2. Verify git state
    if not verify_git_state(checkpoint):
        raise HandoffError(
            "Git state changed since handoff. "
            "Run 'git stash' or 'git checkout .' to restore."
        )

    # 3. Recreate execution
    execution = Execution.from_checkpoint(checkpoint)

    # 4. Output resume message
    output(f"""
══════════════════════════════════════════════════════════════
 RESUMING FROM HANDOFF
══════════════════════════════════════════════════════════════

 Checkpoint: {checkpoint.id}
 Task: {checkpoint.task_input[:50]}...

 Progress: {checkpoint.current_phase}/{checkpoint.total_phases} phases

 Continuing with Phase {checkpoint.current_phase + 1}...

══════════════════════════════════════════════════════════════
""")

    return execution
```

## Integration with claude-agi

### Orchestrator Loop

```bash
#!/usr/bin/env bash
# claude-agi orchestrator

while true; do
    # Run Claude Code
    claude --continue

    # Check for handoff signal
    if [[ -f "$HANDOFF_SIGNAL" ]]; then
        checkpoint_id=$(jq -r '.checkpoint_id' "$HANDOFF_SIGNAL")
        rm "$HANDOFF_SIGNAL"

        echo "Handoff detected. Starting new session..."
        echo "Checkpoint: $checkpoint_id"

        # Brief pause
        sleep 2

        # Continue with checkpoint
        continue
    fi

    # Check if done
    status=$(yq '.status' "$STATE_FILE")
    if [[ "$status" == "completed" ]]; then
        echo "Task completed!"
        break
    fi

    # Unexpected exit
    echo "Session ended unexpectedly. Checking state..."
    sleep 5
done
```

### State Updates

Handoff manager updates these state files:

```yaml
# .claude/auto-execution/state.yaml
status: handoff_requested
current_task: task-3
checkpoint_id: chk-20250126-143000

# .claude/auto-execution/.handoff-requested
{
  "requested_at": "2025-01-26T14:30:00Z",
  "checkpoint_id": "chk-20250126-143000",
  "reason": "token_limit"
}
```

## Output Examples

### Approaching Limit

```
→ Faza 2/5: Route Handlers
  ✓ Route Handlers (12/12 tests)

  ! Token usage: 72% - approaching limit
  → Checking if Phase 3 fits...
  → Estimated: 8,000 tokens, Available: 28,000
  → Continuing...

→ Faza 3/5: Middleware
  ...
```

### Handoff Triggered

```
→ Faza 3/5: Middleware Updates
  ✓ Middleware Updates (6/6 tests)

  ! Token limit reached (82%)
  → Completing current operation...
  → Creating checkpoint...
  → Signaling handoff...

══════════════════════════════════════════════════════════════
 SESSION HANDOFF
══════════════════════════════════════════════════════════════

 Progress: 3/5 phases complete
 Checkpoint: chk-20250126-143000

 Token usage: 82,000 / 100,000 (82%)

 Resume command:
 claude-agi --continue

══════════════════════════════════════════════════════════════
```

### Resumed Session

```
══════════════════════════════════════════════════════════════
 RESUMING FROM HANDOFF
══════════════════════════════════════════════════════════════

 Checkpoint: chk-20250126-143000
 Task: Major API refactoring with new authentication...

 Progress: 3/5 phases

 Continuing with Phase 4...

══════════════════════════════════════════════════════════════

→ Faza 4/5: Auth Integration
  → RED: Writing tests...
  ...
```

## Configuration

```yaml
# .claude/config.yaml

handoff:
  threshold: 0.80        # 80% of max tokens
  warning_threshold: 0.70
  max_tokens: 100000

  # What to include in context summary
  context_summary:
    max_decisions: 10
    max_gotchas: 5
    include_git_diff: true

  # Orchestrator settings
  orchestrator:
    enabled: true
    auto_continue: true
    pause_between_sessions: 2  # seconds
```
