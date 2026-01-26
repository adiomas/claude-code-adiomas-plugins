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

## Overnight Mode

For long-running tasks, use the external orchestrator:

```bash
# Interactive (with prompts)
claude-agi

# Overnight (no prompts, auto-restart)
claude-agi --overnight
```

See `bin/claude-agi` for details.

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

| Old | New |
|-----|-----|
| `/auto` | `/do` |
| `/auto-smart` | `/do` |
| `/auto-lite` | `/do` (auto-detects simple tasks) |
| `/auto-prepare` | `/do` (auto-prepares if needed) |
| `/auto-execute` | `/do --continue` |
| `/auto-overnight` | `claude-agi --overnight` |
| `/auto-status` | `/status` |
| `/auto-cancel` | `/cancel` |

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

7. **Execute**
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
