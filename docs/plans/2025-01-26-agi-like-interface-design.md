# AGI-Like Interface Design for autonomous-dev Plugin

**Date:** 2025-01-26
**Status:** Approved
**Version:** 4.0 (major redesign)

## Executive Summary

Transformacija autonomous-dev plugina iz kompleksnog multi-command sustava (10 komandi) u AGI-like sučelje s jednom glavnom komandom (`/do`) koja razumije prirodni jezik i automatski odabire najbolju strategiju izvršavanja.

## Design Decisions

| Odluka | Izbor | Razlog |
|--------|-------|--------|
| Memorija | Hibridna (lokalna + globalna) | Projekt-specifično znanje + dijeljeno učenje |
| Nejasnoće | Pametno pogađanje | Autonomno za većinu, pitaj samo za kritično |
| Feedback | Sažet | Ključni koraci bez buke |
| Prioritet | Pouzdanost | TDD, verifikacija, checkpoint-i |

---

## 1. Unified Command Interface

### Jedna komanda za sve: `/do`

```
/do <bilo što na prirodnom jeziku>
```

**Primjeri:**
```
/do Napravi autentifikaciju s Google OAuth
/do Popravi bug - checkout ne radi na mobilnom
/do Zašto je API spor?
/do Ono od jučer, samo s emailom
```

### Eliminira 10 komandi

| Staro | Novo |
|-------|------|
| `/auto`, `/auto-smart`, `/auto-lite`, `/auto-prepare`, `/auto-execute`, `/auto-overnight`, `/auto-continue`, `/auto-plan`, `/auto-audit`, `/auto-cancel` | `/do`, `/status`, `/cancel` |

---

## 2. Intent Engine Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                      INTENT ENGINE                              │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │   PARSER     │───▶│  ENRICHER    │───▶│  CLASSIFIER  │     │
│  │              │    │              │    │              │     │
│  │ NLP analysis │    │ Add memory   │    │ Determine    │     │
│  │ Extract      │    │ Add project  │    │ intent type  │     │
│  │ entities     │    │ context      │    │ & complexity │     │
│  └──────────────┘    └──────────────┘    └──────────────┘     │
│                                                    │           │
│                                                    ▼           │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │   EXECUTOR   │◀───│  STRATEGIST  │◀───│  RESOLVER    │     │
│  │              │    │              │    │              │     │
│  │ Run with     │    │ Pick best    │    │ Fill gaps    │     │
│  │ TDD + verify │    │ approach     │    │ Ask if needed│     │
│  └──────────────┘    └──────────────┘    └──────────────┘     │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### Komponente

| Komponenta | Uloga | Primjer |
|------------|-------|---------|
| **Parser** | Razumije prirodni jezik | "ono od jučer" → referenca na prethodni task |
| **Enricher** | Dodaje kontekst iz memorije | Zna da projekt koristi Next.js, Supabase |
| **Classifier** | Određuje tip i kompleksnost | FEATURE, complexity 3, FRONTEND |
| **Resolver** | Rješava nejasnoće | Ako kritično → pitaj, inače → odluči |
| **Strategist** | Bira pristup | DIRECT (1-2) ili ORCHESTRATED (3-5) |
| **Executor** | Izvršava s TDD | Piše test → kod → verify → learn |

### Reference Resolution (AGI-like)

```
Input: "Ono s loginima ne radi"

Parser detektira:
  - "ono" → REFERENCE (prethodni rad)
  - "s loginima" → SCOPE (login flow)
  - "ne radi" → TYPE (bug fix)

Enricher provjerava memoriju:
  - Jučer radili: authentication feature
  - Files: src/auth/login.ts, src/middleware/auth.ts

Resolver:
  - Dovoljno konteksta? DA
  - Kritična akcija? NE
  - → Nastavi bez pitanja

Output razumijevanja:
  "Bug fix u login flow-u (src/auth/login.ts)"
```

---

## 3. Hybrid Memory System

### Struktura memorije

```
~/.claude/                          # GLOBALNA MEMORIJA
└── global-memory/
    ├── patterns.yaml               # Naučeni obrasci (svi projekti)
    ├── preferences.yaml            # Korisničke preferencije
    └── tech-knowledge.yaml         # Tehnološko znanje

<projekt>/.claude/                  # LOKALNA MEMORIJA
└── memory/
    ├── project-context.yaml        # Specifičnosti projekta
    ├── session-history.yaml        # Povijest sesija
    └── learnings.yaml              # Naučeno na ovom projektu
```

### Globalna memorija (dijeli se između projekata)

```yaml
# ~/.claude/global-memory/patterns.yaml
patterns:
  authentication:
    approach: "bcrypt za passwords, JWT 24h expiry"
    learned_from: ["projekt-a/2024-12", "projekt-b/2025-01"]
    success_rate: 100%

  error_handling:
    approach: "Try-catch na granicama, custom Error klase"
    learned_from: ["projekt-c/2025-01"]
    success_rate: 95%

# ~/.claude/global-memory/preferences.yaml
preferences:
  code_style: "functional over OOP where possible"
  testing: "prefer integration tests over unit"
  commits: "conventional commits format"
```

### Lokalna memorija (projekt-specifična)

```yaml
# <projekt>/.claude/memory/project-context.yaml
project:
  name: "my-saas-app"
  stack: "Next.js 14, Supabase, Tailwind"
  test_runner: "vitest"  # NE jest!
  quirks:
    - "Async Supabase client - await everything"
    - "CSS modules, not Tailwind classes directly"

recent_work:
  - date: "2025-01-25"
    task: "Google OAuth authentication"
    files: ["src/auth/google.ts", "src/middleware/auth.ts"]
    decisions:
      - "JWT u httpOnly cookie"
      - "Refresh token rotation"
```

---

## 4. Adaptive Execution Strategy

### Automatski odabir strategije

| Complexity | Mode | Karakteristike |
|------------|------|----------------|
| 1-2 | DIRECT | Simple, few files, clear scope |
| 3-5 | ORCHESTRATED | Complex, many files, needs phases |

### Dvije strategije izvršavanja

```
DIRECT (Complexity 1-2)              ORCHESTRATED (Complexity 3-5)
━━━━━━━━━━━━━━━━━━━━━━━              ━━━━━━━━━━━━━━━━━━━━━━━━━━━━

→ Understand                         → Decompose into phases
→ Implement (TDD)                    → For each phase:
→ Verify                                 → Implement (TDD)
→ Done                                   → Verify
                                         → Checkpoint
                                     → Final verification
                                     → Done
```

### Nevidljivi checkpoint sustav

Korisnik vidi samo progress, sustav interno upravlja:
- Token usage tracking
- Automatic checkpointing at 70%, 80%, 90%
- Seamless session handoff when needed

---

## 5. Unified State (Jedan Izvor Istine)

### Jedan JSON umjesto 7+ fileova

```
PRIJE:                               POSLIJE:
.claude/                             .claude/
├── auto-state-machine.yaml          └── state.json  ← SVE OVDJE
├── auto-context.yaml
├── project-profile.yaml
├── plans/auto-*.md
├── auto-execution/
│   ├── state.yaml
│   ├── tasks.json
│   └── ...
└── smart-ralph/state.yaml
```

### State Schema

```typescript
interface UnifiedState {
  version: "2.0";

  task: {
    input: string;
    intent: "FEATURE" | "BUG_FIX" | "RESEARCH" | "REFACTOR" | "QUESTION";
    complexity: 1 | 2 | 3 | 4 | 5;
    work_type: "FRONTEND" | "BACKEND" | "FULLSTACK";
    started_at: string; // ISO8601
  };

  project: {
    stack: string;
    test_cmd: string;
    build_cmd: string;
    lint_cmd: string;
  };

  execution: {
    strategy: "DIRECT" | "ORCHESTRATED";
    status: "running" | "paused" | "done" | "failed";
    current_phase?: number;
    phases: Phase[];
  };

  evidence: {
    [phaseId: string]: {
      claim: string;
      proof: string;
      verified_at: string;
    };
  };

  context: {
    tokens_used: number;
    key_decisions: string[];
    checkpoint_ready: boolean;
  };

  recovery: {
    last_checkpoint: string;
    can_resume: boolean;
    resume_from: string;
  };
}
```

---

## 6. Self-Learning System

### Learning Pipeline

```
SESIJA ZAVRŠAVA
     │
     ▼
┌─────────────┐
│  ANALYZER   │ Što je radilo? Što nije?
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  EXTRACTOR  │ Izvuci obrasce, odluke, greške
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌─────────────┐
│   LOCAL     │     │   GLOBAL    │
│   MEMORY    │     │   MEMORY    │
└─────────────┘     └─────────────┘
```

### Automatsko učenje

**Uspješne sesije:**
- Izvuci pristupe koji su radili
- Ažuriraj confidence score (+)
- Spremi key decisions

**Failovi:**
- Analiziraj root cause
- Spremi kao "gotcha"
- Ažuriraj confidence score (-)

### Confidence Adjustment

```
Pattern: "bcrypt za passwords"
Initial confidence: 0.8

Korišteno 5x → sve uspješno
New confidence: 0.95

Korišteno 1x → failalo
New confidence: 0.85
Added note: "za high-security, razmotri argon2"
```

---

## 7. User Experience

### Sažet feedback

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

### Kritične akcije (MORA pitati)

```
> /do Obriši sve test fileove

⚠️  DESTRUKTIVNA AKCIJA

Ovo će obrisati 23 test filea.
Jesi li siguran? [Da] [Ne]
```

### Pametno pogađanje

```
> /do Dodaj validation

# NE pita jer:
# - react-hook-form postoji
# - Memorija: "zod za validation"
# - Nije destruktivno

→ Dodajem Zod validation... ✓
✓ Gotovo. Koristio sam Zod (kao prije).
```

---

## 8. Implementation Plan

### Nova struktura plugina

```
autonomous-dev/
├── manifest.json
├── commands/
│   ├── do.md            # GLAVNA KOMANDA
│   ├── status.md
│   └── cancel.md
├── engine/              # INTENT ENGINE
│   ├── parser.md
│   ├── enricher.md
│   ├── classifier.md
│   ├── resolver.md
│   ├── strategist.md
│   └── executor.md
├── memory/              # MEMORY SYSTEM
│   ├── local-manager.md
│   ├── global-manager.md
│   └── learner.md
├── execution/           # EXECUTION
│   ├── direct-mode.md
│   ├── orchestrated-mode.md
│   ├── checkpoint.md
│   └── handoff.md
├── skills/              # INTERNAL (smanjeno)
│   ├── project-detector/
│   ├── verification-runner/
│   └── tdd-executor/
├── agents/              # SUBAGENTS (smanjeno)
│   ├── task-executor.md
│   └── verifier.md
└── hooks/
    ├── hooks.json
    └── session-end.sh
```

### Migration Path

| Faza | Opis | Trajanje |
|------|------|----------|
| 1 | `/do` kao alias za postojeću logiku | 1 tjedan |
| 2 | Unified state.json | 1 tjedan |
| 3 | Intent Engine | 2 tjedna |
| 4 | Learning System | 2 tjedna |
| 5 | Cleanup starih komandi | 1 tjedan |

---

## Success Criteria

1. **Simplicity:** 3 komande umjesto 10
2. **AGI-like:** Razumije "ono od jučer" reference
3. **Learning:** Poboljšava se s vremenom
4. **Reliability:** TDD + verification na svemu
5. **User Experience:** Sažet, jasan feedback

---

## References

- [Anthropic: Building agents with Claude Agent SDK](https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk)
- [Anthropic: Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Anthropic: Claude Code best practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- [Cursor 2.0 Multi-Agent Architecture](https://www.artezio.com/pressroom/blog/revolutionizes-architecture-proprietary/)
- [Devin: Autonomous AI Software Engineer](https://devin.ai/agents101)
