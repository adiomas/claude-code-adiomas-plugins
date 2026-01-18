# Skill Chains for Autonomous Development

Defines which skills should automatically invoke other skills based on work type and phase.

## Chain Definitions

### Frontend Development Chain

When `work_type == FRONTEND` AND task involves multiple components:

```
1. frontend-design
   └── Establishes design vision, component structure
       │
       ▼
2. task-decomposer (AUTO-INVOKE if >= 3 components)
   └── Breaks into parallel tasks with dependencies
       │
       ▼
3. parallel-orchestrator (if parallelization enabled)
   └── Creates worktrees, dispatches agents
       │
       ▼
4. task-executor × N (parallel execution)
   └── Each follows TDD in isolated worktree
       │
       ▼
5. integration-validator (pre-merge)
   └── Validates all branches together
       │
       ▼
6. webapp-testing (post-merge)
   └── Visual verification, screenshots
```

### Backend Development Chain

When `work_type == BACKEND` AND task involves multiple endpoints/services:

```
1. architecture-patterns
   └── Defines service structure, patterns
       │
       ▼
2. task-decomposer (AUTO-INVOKE if >= 3 endpoints)
   └── Breaks into parallel tasks
       │
       ▼
3. parallel-orchestrator (if parallelization enabled)
   └── Creates worktrees, dispatches agents
       │
       ▼
4. task-executor × N (parallel execution)
   └── Each follows TDD in isolated worktree
       │
       ▼
5. integration-validator (pre-merge)
   └── Validates all branches + schema
       │
       ▼
6. schema-validator (if database detected)
   └── Validates DB types match code
```

### Fullstack Development Chain

When `work_type == FULLSTACK`:

```
1. architecture-patterns + frontend-design
   └── Both run to establish full picture
       │
       ▼
2. task-decomposer (AUTO-INVOKE)
   └── Identifies backend vs frontend tasks
       │
       ▼
3. parallel-orchestrator
   └── Groups: [backend tasks] || [frontend tasks]
       │
       ▼
4. task-executor × N
   └── Backend and frontend can run in parallel!
       │
       ▼
5. integration-validator
   └── Tests API contracts between layers
       │
       ▼
6. schema-validator + webapp-testing
   └── Both verification types
```

## Auto-Invoke Rules

### When to Auto-Invoke task-decomposer

| Condition | Action |
|-----------|--------|
| Plan has >= 3 distinct output files | AUTO-INVOKE |
| Plan has >= 3 tasks marked independent | AUTO-INVOKE |
| Plan has single file | SKIP |
| All tasks have linear dependencies | SKIP |
| work_type == RESEARCH | SKIP |

### When to Auto-Invoke parallel-orchestrator

| Condition | Action |
|-----------|--------|
| task-decomposer found >= 3 independent tasks | AUTO-INVOKE |
| task-decomposer found parallel groups | AUTO-INVOKE |
| All tasks sequential | SKIP |
| parallelization.enabled == false in config | SKIP |

### When to Auto-Invoke integration-validator

| Condition | Action |
|-----------|--------|
| Multiple worktrees created | AUTO-INVOKE before merge |
| Any auto/* branches exist | AUTO-INVOKE |
| Single branch work | SKIP |

## Configuration

In `.claude/auto-context.yaml`:

```yaml
skill_chains:
  frontend:
    auto_invoke_decomposer: true
    auto_invoke_parallel: true
    min_components: 3

  backend:
    auto_invoke_decomposer: true
    auto_invoke_parallel: true
    min_endpoints: 3

  fullstack:
    auto_invoke_decomposer: true
    auto_invoke_parallel: true
    parallel_layers: true  # Run backend + frontend in parallel
```

## Chain Execution Logging

When chains execute, output:

```
⛓️ Skill Chain: FRONTEND
   ├── ✅ frontend-design (completed)
   ├── ⏳ task-decomposer (auto-invoked)
   │   └── Found: 5 independent tasks
   ├── ⏳ parallel-orchestrator (auto-invoked)
   │   └── Created: 2 parallel groups
   └── ⏸️ integration-validator (pending)
```

## Overriding Chains

User can override auto-invoke behavior:

```yaml
# In .claude/auto-context.yaml
skill_chains:
  override:
    skip_decomposer: true   # Force sequential
    skip_parallel: true     # Disable parallelization
    force_parallel: true    # Force parallel even with < 3 tasks
```

## Progressive Skill Loading (Anthropic Best Practice)

**Load skills lazily, not eagerly, to reduce context consumption by 85%.**

Instead of loading all skills upfront (~47K tokens), load only what's needed for the current phase (~7K tokens).

### Lazy Loading References

Replace eager loading with lazy references in chains:

```
BEFORE (Eager - loads all ~47K tokens):
skill_chain:
  - load: frontend-design       # ~1500 tokens
  - load: task-decomposer       # ~800 tokens
  - load: parallel-orchestrator # ~1200 tokens
  - load: verification-runner   # ~600 tokens
  - load: mutation-tester       # ~500 tokens
  - load: conflict-resolver     # ~400 tokens
  - load: e2e-validator         # ~700 tokens
  ... (continues for all skills)

AFTER (Lazy - loads ~7K tokens per phase):
skill_chain:
  - ref: frontend-design        # Invoked via Skill tool when needed
  - ref: task-decomposer        # Loaded only in BRAINSTORM phase
  - ref: parallel-orchestrator  # Loaded only in PARALLELIZE phase
  - ref: verification-runner    # Loaded only in EXECUTE phase
  ... (each loaded only when its phase begins)
```

### Configuration Reference

See `skills/skill-loading-config.yaml` for:
- `always_loaded`: Core skills loaded every session (~1K tokens)
- `phase_specific`: Skills loaded per phase (~3K tokens max)
- `on_demand`: Conditional skills (~1.5K tokens max)

### Phase Transition Hook

When phase changes, the hook outputs which skills to load:

```bash
# Called by state-transition.sh
${CLAUDE_PLUGIN_ROOT}/hooks/phase-transition-hook.sh EXECUTE
```

Output:
```
Progressive Skill Loading - Phase: EXECUTE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Always Loaded Skills:
  ✓ project-detector
  ✓ work-type-classifier

Phase-Specific Skills for EXECUTE:
  ✓ verification-runner
  ✓ mutation-tester

Estimated Token Usage:
  Always loaded: ~1000 tokens
  Phase-specific: ~1100 tokens
  ─────────────────────
  Total: ~2100 tokens (budget: 7000)
```

### Implementation in Agents

Agents should follow progressive loading:

```yaml
# In agent prompts
1. Read current phase from .claude/auto-state-machine.yaml
2. Check skills/skill-loading-config.yaml for phase skills
3. Load ONLY those skills (via Skill tool)
4. Never pre-load skills for future phases
```

### Token Savings

| Loading Strategy | Tokens | Savings |
|-----------------|--------|---------|
| Eager (all skills) | ~47,000 | 0% |
| Progressive (per phase) | ~7,000 | 85% |
| Minimal (core only) | ~2,000 | 96% |

Progressive loading enables longer sessions with more context for actual work.
