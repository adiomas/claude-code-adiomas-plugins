---
name: do
description: |
  AGI-Like Unified Command - one command to rule them all.
  Replaces /auto, /auto-smart, /auto-lite. Just describe what you want.
argument-hint: "<task in natural language>"
allowed-tools: ["Task", "Bash", "Read", "Write", "Edit", "Glob", "Grep", "TodoWrite", "WebFetch", "AskUserQuestion", "Skill"]
---

# /do - AGI-Like Unified Command

One command to rule them all. Replaces `/auto`, `/auto-smart`, `/auto-lite`, and all other `/auto-*` commands.

```
/do <anything in natural language>
```

## Examples

```
/do Napravi autentifikaciju s Google OAuth
/do Popravi bug - checkout ne radi na mobilnom
/do Zašto je API spor?
/do Ono od jučer, samo s emailom
/do Add dark mode with system preference detection
```

## How It Works

```
┌──────────────────────────────────────────────────────────────────┐
│ /do "Ono od jučer ne radi, popravi i dodaj error handling"       │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
         ┌────────────────────────────────────────┐
         │           INTENT ENGINE                 │
         │                                         │
         │  Parser → Enricher → Classifier         │
         │     → Resolver → Strategist             │
         └────────────────────────────────────────┘
                              │
                              ▼
         ┌────────────────────────────────────────┐
         │           EXECUTION                     │
         │                                         │
         │  DIRECT (simple) or ORCHESTRATED (complex)
         │  With TDD, checkpoints, and verification │
         └────────────────────────────────────────┘
                              │
                              ▼
         ┌────────────────────────────────────────┐
         │             RESULT                      │
         │                                         │
         │  ✓ Gotovo. Verificirano. Evidence.      │
         └────────────────────────────────────────┘
```

## Intent Engine Pipeline

### 1. Parser

Parses natural language input:
- Extracts entities (files, features, components)
- Resolves references ("ono od jučer" → yesterday's session)
- Detects intent type (FEATURE, BUG_FIX, REFACTOR, etc.)
- Splits composite requests ("X i Y" → [task X, task Y])

### 2. Enricher

Adds context from memory:
- Loads project context (stack, commands, quirks)
- Loads local memory (recent sessions, project patterns)
- Loads global memory (universal patterns, gotchas)
- Finds similar past work

### 3. Classifier

Classifies the intent:
- **Type**: FEATURE | BUG_FIX | REFACTOR | RESEARCH | QUESTION
- **Complexity**: 1-5 scale
- **Work Type**: FRONTEND | BACKEND | FULLSTACK

### 4. Resolver

Handles ambiguity and critical actions:
- If critical action (delete, security change) → **ASK**
- If low confidence → **ASK** for clarification
- Otherwise → **PROCEED** autonomously

### 5. Strategist

Selects execution strategy:
- **DIRECT** (complexity 1-2): Simple loop, no checkpoints
- **ORCHESTRATED** (complexity 3-5): Phases, TDD, checkpoints

## Execution Modes

### DIRECT Mode (Complexity 1-2)

```
→ Understand
→ Implement
→ Verify
→ Done
```

Fast execution for simple tasks. No checkpoints needed.

### ORCHESTRATED Mode (Complexity 3-5)

```
For each phase:
  → Checkpoint(start)
  → TDD: RED → GREEN → REFACTOR
  → Verify phase
  → Checkpoint(complete)
Final verification
→ Done
```

Full discipline with checkpoints for complex tasks.

## Reference Resolution

The magic that makes "ono od jučer" work:

| Input | Meaning | Resolution |
|-------|---------|------------|
| "ono" | Last thing worked on | Most recent session |
| "ono od jučer" | Yesterday's work | Filter by date |
| "ono s loginima" | Login-related work | Semantic search: "login" |
| "nastavi" | Continue unfinished | Filter status=incomplete |
| "isto kao prije" | Same approach | Copy from similar task |

## Critical Actions

Always asks before:
- **Deletion**: Removing files, data, or functionality
- **Security**: Changing auth, permissions, tokens
- **Database**: Migrations, schema changes
- **Breaking changes**: API modifications

```
⚠️  DESTRUKTIVNA AKCIJA

Ovo će obrisati 23 test filea.
Jesi li siguran? [Da] [Ne]
```

## Memory Integration

### Local Memory (Project-specific)

- Project context (stack, quirks)
- Recent sessions (last 90 days)
- Project-specific patterns

### Global Memory (Shared)

- Universal patterns by domain
- Technology gotchas
- User preferences

### Conflict Resolution

When local and global conflict, confidence-based resolution decides.
Local wins for recent/project-specific. Global wins for established patterns.

## Output Style

Concise feedback without noise:

```
> /do Napravi dark mode

Razumijem: Dark mode za Next.js app (complexity 3/5)

→ Kreiram ThemeProvider... ✓
→ Dodajem useTheme hook... ✓
→ Implementiram toggle... ✓
→ Verificiram...

✓ Gotovo.

  Kreirano:
  • src/providers/ThemeProvider.tsx
  • src/hooks/useTheme.ts

  Verificirano:
  • Tests: 8/8 passing
  • Build: success

  Commit? [Da] [Ne] [Pregledaj]
```

## Session Handoff

At 80% token usage, automatic handoff:

```
→ Nastavljam u novoj sesiji...

Progress: 2/4 faza
Checkpoint: chk-20250126-103000

Za nastavak, u novoj sesiji pokreni:
  /do --continue

Ili će se automatski nastaviti ako koristiš overnight mode.
```

## Command Options

```
/do <task>                    # Standard execution
/do --continue                # Resume from checkpoint
/do --status                  # Check progress (alias for /status)
/do --cancel                  # Cancel execution (alias for /cancel)
```

## Execution Modes: In-Session vs Overnight

### /do = In-Session Execution (THIS COMMAND)

`/do` plans and executes **immediately in the current session**:

```
/do Napravi dark mode
→ Planira
→ Pita za odobrenje
→ ODMAH IZVRŠAVA
→ Gotovo (u istoj sesiji)
```

Use `/do` when you:
- Want to stay in the session and watch progress
- Have simpler tasks (complexity 1-3)
- Don't need overnight execution

### /auto-prepare + claude-agi = Overnight Mode

For long-running tasks that need overnight/unattended execution:

```bash
# Step 1: Prepare (interactive planning)
claude -p "/auto-prepare Napravi autentifikaciju s OAuth"
# This creates state files and exits

# Step 2: Execute (autonomous)
claude-agi --overnight
```

`/auto-prepare` creates state files that `claude-agi` needs:
- `.claude/auto-execution/state.yaml`
- `.claude/auto-execution/tasks.json`
- `.claude/auto-execution/next-session.md`

Use this when you:
- Want unattended overnight execution
- Have complex tasks (complexity 4-5)
- Want to preserve context (planning separate from execution)

**IMPORTANT:** `/do` does NOT create state files for `claude-agi`.
If you plan to use `claude-agi`, use `/auto-prepare` instead of `/do`.

See `bin/claude-agi --help` for details.

## Learning

After successful completion:
1. Extracts patterns that worked
2. Records decisions made
3. Stores gotchas encountered
4. Updates confidence scores

This makes future similar tasks faster and more accurate.

## Related

- `/status` - Check execution progress
- `/cancel` - Cancel and cleanup
- `claude-agi` - External orchestrator for multi-session

## Migration from Old Commands

| Old | New | Notes |
|-----|-----|-------|
| `/auto` | `/do` | In-session execution |
| `/auto-smart` | `/do` | Auto-detects complexity |
| `/auto-lite` | `/do` | Auto-detects simple tasks |
| `/auto-prepare` | `/auto-prepare` | **Still needed for overnight mode!** |
| `/auto-execute` | `/do --continue` | In-session resume |
| `/auto-overnight` | `claude-agi --overnight` | Use with `/auto-prepare` |
| `/auto-status` | `/status` | - |
| `/auto-cancel` | `/cancel` | - |

**Key distinction:**
- `/do` = In-session (planira i odmah izvršava)
- `/auto-prepare` + `claude-agi` = Overnight mode (planira, izlazi, izvršava kasnije)

---

## Implementation

This command uses the following engine skills:

| Skill | Purpose |
|-------|---------|
| engine/parser.md | Parse natural language |
| engine/enricher.md | Add memory context |
| engine/classifier.md | Classify intent |
| engine/resolver.md | Handle ambiguity |
| engine/strategist.md | Select strategy |

And execution skills:

| Skill | Purpose |
|-------|---------|
| execution/direct-executor.md | Simple execution |
| execution/orchestrated-executor.md | Phased execution |
| execution/checkpoint-manager.md | State management |
| execution/handoff-manager.md | Session handoff |

## Pipeline Invocation

When `/do` is invoked:

1. **Load Memory**
   ```
   Invoke: memory/local-manager.md (load)
   Invoke: memory/global-manager.md (load --tech detected)
   ```

2. **Parse Intent**
   ```
   Invoke: engine/parser.md
   ```

3. **Enrich with Context**
   ```
   Invoke: engine/enricher.md
   ```

4. **Classify**
   ```
   Invoke: engine/classifier.md
   ```

5. **Resolve Ambiguity**
   ```
   Invoke: engine/resolver.md

   If critical action → Ask user
   If low confidence → Ask for clarification
   Otherwise → Proceed
   ```

6. **Select Strategy**
   ```
   Invoke: engine/strategist.md

   If complexity <= 2 → DIRECT
   If complexity >= 3 → ORCHESTRATED
   ```

7. **Plan Approval Gate** (ORCHESTRATED only)

   ⚠️ **ENFORCED BY HOOK**: `hooks/enforce-plan-approval.sh` will BLOCK
   Edit/Write operations if this step is skipped!

   ```
   IF strategy == ORCHESTRATED AND complexity >= 3:

     1. Mark /do session active:
        Bash: ${CLAUDE_PLUGIN_ROOT}/scripts/set-plan-approved.sh start-do

     2. Write plan to .claude/plans/{session-id}.md
        - Include: phases, files, estimated tokens
        - Include: TDD requirements, verification steps

     3. Display plan summary to user:
        "Plan spreman za: {task_summary}
         Mode: ORCHESTRATED ({num_phases} faza)
         Estimated: {token_estimate} tokena

         Faze:
         1. {phase_1_name} - {phase_1_desc}
         2. {phase_2_name} - {phase_2_desc}
         ..."

     4. **MANDATORY: Use AskUserQuestion tool**
        Question: "Želiš li nastaviti s implementacijom?"
        Options:
          - "Nastavi" → Set approval and proceed
          - "Pregledaj plan" → Show full plan, then ask again
          - "Odustani" → Exit gracefully

     5. IF user confirms "Nastavi":
        Bash: ${CLAUDE_PLUGIN_ROOT}/scripts/set-plan-approved.sh true
        (This sets plan_approved=true in state, allowing Edit/Write)

     6. IF user selects "Odustani":
        Bash: ${CLAUDE_PLUGIN_ROOT}/scripts/set-plan-approved.sh end-do
        Exit gracefully

     7. ONLY proceed to step 8 if user explicitly confirms
        DO NOT auto-proceed. DO NOT skip this step.
        The PreToolUse hook will BLOCK any Edit/Write attempts!

   IF strategy == DIRECT:
     Skip to step 8 (no approval needed for simple tasks)
   ```

8. **Execute**
   ```
   If DIRECT:
     Invoke: execution/direct-executor.md
   If ORCHESTRATED:
     Invoke: execution/orchestrated-executor.md
   ```

8. **On Success**
   ```
   Invoke: memory/learner.md (extract learnings)
   Update confidence scores
   Offer to commit
   ```

9. **On Failure**
   ```
   Invoke: execution/failure-handler.md
   Escalate: Retry → Pivot → Research → Ask
   ```

10. **On Token Limit**
    ```
    Invoke: execution/handoff-manager.md
    Create checkpoint
    Signal orchestrator
    ```
