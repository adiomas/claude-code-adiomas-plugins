# Feature: AGI-Like Interface v4.0

## Progress: 0/27 tasks complete (0%)

### Status: Ready for Execution

Prepared by `/auto-prepare` at 2025-01-26T12:00:00Z
Plan: `docs/plans/2025-01-26-agi-implementation-plan.md`

---

## Pending Tasks

### Phase 0: External Orchestrator
- [ ] task-0.1: Create claude-agi orchestrator script
- [ ] task-0.2: Create handoff request script
- [ ] task-0.3: Create installation script

### Phase 1: Foundation
- [ ] task-1.1: Create /do command
- [ ] task-1.2: Create unified state schema and manager
- [ ] task-1.3: Create /status command
- [ ] task-1.4: Create /cancel command

### Phase 2: Intent Engine
- [ ] task-2.1: Create Intent Parser skill
- [ ] task-2.2: Create Intent Enricher skill
- [ ] task-2.3: Create Intent Classifier skill
- [ ] task-2.4: Create Intent Resolver skill
- [ ] task-2.5: Create Execution Strategist skill

### Phase 3: Memory System
- [ ] task-3.1: Create Local Memory Manager
- [ ] task-3.2: Create Global Memory Manager
- [ ] task-3.3: Create Learning Extractor
- [ ] task-3.4: Create Forgetter (memory cleanup)

### Phase 4: Execution Engine
- [ ] task-4.1: Create Direct Executor
- [ ] task-4.2: Create Orchestrated Executor
- [ ] task-4.3: Create Checkpoint Manager skill
- [ ] task-4.4: Create Failure Handler
- [ ] task-4.5: Create Handoff Manager
- [ ] task-4.6: Create TDD Executor

### Phase 5: Integration
- [ ] task-5.1: Update hooks.json
- [ ] task-5.2: Create session-end learning hook
- [ ] task-5.3: Update plugin manifest
- [ ] task-5.4: Deprecate old commands

### Phase 6: Testing & Documentation
- [ ] task-6.1: Create integration test
- [ ] task-6.2: Update README
- [ ] task-6.3: Create migration guide

---

## Verification History

| Timestamp | Tests | Lint | Build | Notes |
|-----------|-------|------|-------|-------|
| (none yet) | - | - | - | - |

---

## Key Decisions

1. **Hibridna memorija** - Lokalna (90 dana) + Globalna (zauvijek s cleanup-om)
2. **Pametno pogađanje** - Autonomno osim za kritične akcije
3. **Sažet feedback** - Ključni koraci, bez buke
4. **Pouzdanost** - TDD za complexity 3+, verifikacija svega
5. **External orchestrator** - `claude-agi` za pravu autonomiju
6. **ML complexity scoring** - Heuristika → nauči iz iskustva
7. **Escalating failure** - Retry → Pivot → Research → Ask
8. **80% handoff** - Token limit trigger za novu sesiju
