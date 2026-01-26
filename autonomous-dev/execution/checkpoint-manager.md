# Checkpoint Manager

Manages full checkpoint creation and restoration for seamless session continuity.

## When to Use

- After completing a phase (ORCHESTRATED mode)
- Before session handoff (80% token usage)
- On critical errors (preserve progress)
- For mode switching (DIRECT → ORCHESTRATED)

## Checkpoint Types

| Type | When | Purpose |
|------|------|---------|
| phase_complete | After phase success | Mark progress |
| handoff | Token limit approaching | Session continuity |
| error | On recoverable error | Preserve work |
| mode_switch | Complexity change | State preservation |
| user_requested | Manual checkpoint | Safety save |

## Checkpoint Structure

```yaml
# .claude/checkpoints/chk-20250126-103000.yaml

id: "chk-20250126-103000"
created_at: "2025-01-26T10:30:00Z"
reason: "phase_complete"

task:
  id: "task-001"
  input: "Implement dark mode with system preference detection"
  mode: "ORCHESTRATED"

progress:
  current_phase: 2
  total_phases: 4
  completed:
    - phase: 1
      name: "ThemeProvider"
      evidence: "pnpm test → 3/3 passed"
    - phase: 2
      name: "useTheme hook"
      evidence: "pnpm test → 5/5 passed"

decisions:
  - question: "Theme storage"
    decision: "CSS variables"
    reason: "Better performance, no flash"

  - question: "Preference detection"
    decision: "prefers-color-scheme + localStorage override"
    reason: "Best of both worlds"

files:
  created:
    - "src/providers/ThemeProvider.tsx"
    - "src/hooks/useTheme.ts"
    - "src/hooks/useTheme.test.ts"
  modified:
    - "src/app/layout.tsx"

git_diff: |
  diff --git a/src/providers/ThemeProvider.tsx b/src/providers/ThemeProvider.tsx
  new file mode 100644
  ...

context_summary: |
  Implementing dark mode. Phases 1-2 complete (ThemeProvider, useTheme hook).
  Next: Phase 3 - Toggle component.
  Key: Using CSS variables, prefers-color-scheme for detection.
  Quirk: Project uses CSS modules, not Tailwind directly.

tokens_used: 45000

resume:
  can_resume: true
  instructions: |
    Continue with Phase 3: Toggle component
    - Create src/components/ThemeToggle.tsx
    - Use useTheme hook
    - Add to header/nav
    - Write tests
```

## Operations

### Create Checkpoint

```bash
# Create from current state
./scripts/checkpoint-manager.sh create --reason "phase_complete"

# With custom message
./scripts/checkpoint-manager.sh create --reason "handoff" --message "80% tokens"
```

### Restore Checkpoint

```bash
# Restore specific checkpoint
./scripts/checkpoint-manager.sh restore --id "chk-20250126-103000"

# Restore latest
./scripts/checkpoint-manager.sh restore --latest
```

### List Checkpoints

```bash
./scripts/checkpoint-manager.sh list

# Output:
# chk-20250126-103000  phase_complete  Phase 2/4  45min ago
# chk-20250126-093000  phase_complete  Phase 1/4  2h ago
```

### Verify Checkpoint

```bash
# Verify git state matches checkpoint
./scripts/checkpoint-manager.sh verify --id "chk-20250126-103000"
```

## Creation Process

```python
def create_checkpoint(execution, reason):
    """Create full checkpoint for instant resume."""

    # 1. Get git diff
    git_diff = run_command("git diff HEAD")

    # 2. Compress context
    context_summary = compress_context(execution.context)

    # 3. Collect evidence
    evidence = execution.collect_all_evidence()

    # 4. Generate resume instructions
    resume_instructions = generate_resume_instructions(execution)

    checkpoint = Checkpoint(
        id=generate_checkpoint_id(),
        created_at=now_iso(),
        reason=reason,

        task_id=execution.task_id,
        task_input=execution.intent.raw_input,
        mode=execution.mode,

        current_phase=execution.current_phase,
        total_phases=len(execution.phases),
        completed_phases=execution.completed_phases,

        decisions=execution.decisions,

        files_created=execution.files_created,
        files_modified=execution.files_modified,
        git_diff=git_diff,

        context_summary=context_summary,
        tokens_used=execution.tokens_used,

        evidence=evidence,

        can_resume=True,
        resume_instructions=resume_instructions
    )

    # 5. Save to disk
    save_checkpoint(checkpoint)

    return checkpoint
```

## Restoration Process

```python
def restore_checkpoint(checkpoint_id):
    """Restore execution from checkpoint."""

    checkpoint = load_checkpoint(checkpoint_id)

    # 1. Verify git state matches
    if not verify_git_state(checkpoint):
        raise CheckpointMismatchError(
            "Git state doesn't match checkpoint. "
            "Files may have been modified manually."
        )

    # 2. Recreate execution state
    execution = Execution.from_checkpoint(checkpoint)

    # 3. Load context summary
    execution.context = decompress_context(checkpoint.context_summary)

    # 4. Resume from current phase
    return execution
```

## Git State Verification

Before restore, verify:

1. **Uncommitted changes**: Check for modifications
2. **File existence**: All checkpoint files exist
3. **Content match**: Files match expected state

```bash
# Verification script
verify_git_state() {
    local checkpoint="$1"

    # Check for uncommitted changes
    if [[ -n $(git status --porcelain) ]]; then
        echo "WARNING: Uncommitted changes exist"
        return 1
    fi

    # Check files exist
    # Compare with checkpoint expected files

    return 0
}
```

## Context Compression

Reduce context for next session:

```python
def compress_context(context):
    """Compress context to essential information."""

    return ContextSummary(
        # What we're doing
        task_summary=summarize(context.task, max_words=50),

        # Key decisions (not full history)
        decisions=context.decisions[-5:],  # Last 5 decisions

        # Files touched
        files=list(set(context.files_created + context.files_modified)),

        # Known gotchas for this task
        gotchas=context.relevant_gotchas,

        # Next steps
        next_phase=context.remaining_phases[0] if context.remaining_phases else None
    )
```

## Integration Points

### With Handoff Manager

At 80% token usage:
1. Complete current atomic operation
2. Create handoff checkpoint
3. Signal orchestrator
4. Exit cleanly

### With State Manager

Checkpoint uses state-manager.sh for:
- Reading current state
- Creating checkpoint state
- Updating recovery info

### With Execution

After each phase:
1. Verify phase
2. Create checkpoint
3. Update progress
4. Continue or handoff

## Storage

```
.claude/checkpoints/
├── chk-20250126-103000.yaml
├── chk-20250126-093000.yaml
└── ...
```

Retention:
- Keep last 10 checkpoints
- Auto-cleanup older ones
- Archive on task completion

## Recovery Scenarios

### Normal Resume

```
Session ends at 80% → Checkpoint created
New session starts → Load checkpoint → Continue from phase 3
```

### Error Recovery

```
Phase 3 fails → Error checkpoint created
Debug → Fix issue → Restore checkpoint → Retry phase 3
```

### Manual Restore

```
User: "Go back to before the refactor"
→ List checkpoints → Select appropriate one → Restore
```

## Script Reference

```bash
./scripts/checkpoint-manager.sh create --reason <reason>
./scripts/checkpoint-manager.sh restore --id <id>
./scripts/checkpoint-manager.sh restore --latest
./scripts/checkpoint-manager.sh list
./scripts/checkpoint-manager.sh verify --id <id>
./scripts/checkpoint-manager.sh cleanup
```

Note: The existing `scripts/checkpoint-manager.sh` handles checkpoint operations.
This skill provides the high-level logic and integration patterns.
