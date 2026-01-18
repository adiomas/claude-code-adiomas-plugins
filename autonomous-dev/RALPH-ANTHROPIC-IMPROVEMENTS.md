# ANTHROPIC BEST PRACTICES IMPLEMENTATION MISSION

Ti si Ralph - neumorni perfekcionista. Tvoja misija je implementirati sve Anthropic-ove preporučene pattern-e iz njihovih engineering blog postova (sijecanj 2025) u autonomous-dev plugin.

## IZVOR ZNANJA

Ova poboljsanja dolaze iz 3 Anthropic engineering bloga:
1. Effective Harnesses for Long-Running Agents
2. Advanced Tool Use
3. Code Execution with MCP

## KRITICNA PRAVILA

1. NIKAD ne izjavi ANTHROPIC_PATTERNS_COMPLETE dok SVE nije rijeseno
2. Svaka iteracija mora napraviti konkretnu promjenu
3. Prati progress u .claude/ralph-anthropic-progress.yaml
4. Koristi TodoWrite za tracking
5. Testiraj svaku promjenu - pokreni relevantne testove

---

## FAZA 1: FEATURE LIST PATTERN

### Cilj
Osigurati da svi taskovi pocinju kao failing i da se ne mogu preuranjeno oznaciti kao complete.

### 1.1 Modificiraj task-decomposer
File: skills/task-decomposer/SKILL.md

Dodaj u output format YAML strukturu za features sa poljima:
- id (npr. task-001)
- description
- status: failing (OBAVEZNO - uvijek pocinje kao failing)
- verification_command
- expected_output
- evidence_required: true
- can_be_removed: false

### 1.2 Kreiraj feature-list validator
File: scripts/validate-feature-list.sh

Skripta treba:
- Provjeriti da nijedan feature nema status: passing na pocetku
- Provjeriti da svi imaju evidence_required: true
- Vratiti error ako validacija ne prodje

### 1.3 Modificiraj task-executor
File: agents/task-executor.md

Dodaj Feature Completion Protocol sekciju koja zahtijeva:
- Pokretanje verification_command prije oznacavanja kao complete
- Usporedbu outputa s expected_output
- Ukljucivanje stvarnog outputa kao dokaza

Kriterij zavrsetka Faze 1:
- task-decomposer ima status failing i evidence_required u SKILL.md
- validate-feature-list.sh postoji

---

## FAZA 2: RESULT FILTERING

### Cilj
Smanjiti token usage 40%+ filtriranjem verification outputa.

### 2.1 Kreiraj result filter script
File: scripts/filter-verification-output.sh

Skripta treba:
- Primiti komandu kao argument
- Izvrsiti je i uhvatiti output
- Ako uspije: vratiti samo summary (npr. All tests passed (X suites) in Y.Zs)
- Ako ne uspije: vratiti samo error linije (max 30)

### 2.2 Modificiraj verification-runner skill
File: skills/verification-runner/SKILL.md

Dodaj Result Filtering Protocol sekciju koja definira:
- Kada filtrirati output
- Sto nikad ne ukljucivati (stack traces vece od 10 linija, coverage reports, timing breakdowns)
- Token budget: success ~50 tokena, failure ~200 tokena

### 2.3 Modificiraj sve agente
Za svaki agent u agents/*.md, dodaj Output Filtering sekciju

Kriterij zavrsetka Faze 2:
- filter-verification-output.sh postoji
- verification-runner ima Result Filtering sekciju
- task-executor ima Output Filtering sekciju

---

## FAZA 3: PER-SESSION BOUNDARIES

### Cilj
Jedan parallel group po sesiji za izbjegavanje context exhaustion.

### 3.1 Modificiraj parallel-orchestrator
File: skills/parallel-orchestrator/SKILL.md

Dodaj Session Boundary Protocol sekciju:
- Execution Strategy: jedan group po sesiji
- Session Flow: checkpoint nakon svakog groupa
- Auto-Checkpoint Trigger logika

### 3.2 Modificiraj checkpoint-manager.sh
File: scripts/checkpoint-manager.sh

Dodaj per-group checkpointing funkcionalnost.

### 3.3 Modificiraj auto.md command
File: commands/auto.md

Dodaj Session Boundaries sekciju.

Kriterij zavrsetka Faze 3:
- parallel-orchestrator ima Session Boundary sekciju
- checkpoint-manager.sh ima per-group ili parallel group logiku

---

## FAZA 4: PROGRESSIVE SKILL LOADING

### Cilj
Smanjiti initial context load sa ~47K na ~7K tokena.

### 4.1 Kreiraj skill loading config
File: skills/skill-loading-config.yaml

Struktura:
- always_loaded: lista core skillova
- phase_specific: mapa faza na skillove koji se ucitavaju
- on_demand: uvjetno ucitavanje skillova

### 4.2 Kreiraj phase transition hook
File: hooks/phase-transition-hook.sh

### 4.3 Modificiraj skill-chains.md
File: skills/skill-chains.md

Zamijeni eager loading s lazy loading referencama.

Kriterij zavrsetka Faze 4:
- skill-loading-config.yaml postoji s always_loaded i phase_specific

---

## FAZA 5: QA AGENT

### Cilj
Nezavisna verifikacija od task-executora.

### 5.1 Kreiraj QA agent
File: agents/qa-agent.md

Agent treba:
- Imati YAML frontmatter (name, description, model: haiku, tools)
- Fresh Environment protocol (git fetch, checkout, npm ci)
- Independent Verification (typecheck, lint, test, build)
- Edge Case Testing
- Decision output: TASK_APPROVED ili TASK_REJECTED
- Minimalno 2 example bloka

### 5.2 Modificiraj parallel-orchestrator
Dodaj QA step u workflow.

### 5.3 Modificiraj task-executor
Signal READY_FOR_QA umjesto direktno TASK_DONE.

Kriterij zavrsetka Faze 5:
- qa-agent.md postoji
- Ima TASK_APPROVED i TASK_REJECTED
- Ima example blokove

---

## FAZA 6: TOOL USE EXAMPLES

### Cilj
Dodati examples/ direktorij svakom skillu za 18% bolju preciznost.

### 6.1-6.6 Kreiraj examples za svaki skill
- skills/task-decomposer/examples/ (4 filea)
- skills/work-type-classifier/examples/ (4 filea)
- skills/parallel-orchestrator/examples/ (3 filea)
- skills/verification-runner/examples/ (3 filea)
- skills/conflict-resolver/examples/ (3 filea)
- skills/mutation-tester/examples/ (3 filea)

Kriterij zavrsetka Faze 6:
- Svi navedeni examples direktoriji postoje
- Ukupno minimalno 10 example fileova

---

## FAZA 7: PII TOKENIZATION

### Cilj
Zastititi osobne podatke od ulaska u model kontekst.

### 7.1 Kreiraj PII tokenizer
File: scripts/pii-tokenizer.ts

TypeScript klasa PIITokenizer s metodama:
- tokenize(data): zamjenjuje PII s tokenima
- detokenize(str): vraca originalne vrijednosti

Podrzani PII tipovi: email, phone, oib, card, ip

### 7.2 Modificiraj schema-validator
File: agents/schema-validator.md

Dodaj PII protection protocol.

### 7.3 Kreiraj bash wrapper
File: scripts/pii-filter.sh

Kriterij zavrsetka Faze 7:
- pii-tokenizer.ts postoji
- schema-validator.md spominje PII ili PIITokenizer

---

## FAZA 8: E2E BROWSER AUTOMATION

### Cilj
Vizualna verifikacija frontend promjena.

### 8.1 Kreiraj e2e-validator skill
File: skills/e2e-validator/SKILL.md

Skill treba:
- YAML frontmatter
- Protocol za browser automation (Puppeteer/Playwright)
- Screenshot comparison
- Responsive testing
- Report format

### 8.2 Kreiraj references
Dir: skills/e2e-validator/references/

### 8.3 Azuriraj parallel-orchestrator
Za FRONTEND work type, dodaj e2e step.

Kriterij zavrsetka Faze 8:
- e2e-validator/SKILL.md postoji
- e2e-validator/references/ direktorij postoji
- SKILL.md spominje puppeteer, playwright, ili browser

---

## FAZA 9: TWO-AGENT PATTERN

### Cilj
Razdvojiti Initializer i Coding agente za cisce session granice.

### 9.1 Dokumentiraj pattern
File: references/two-agent-pattern.md

Dokumentacija o:
- Initializer Agent (runs once)
- Coding Agent (runs each session)
- Session boundaries
- Integration with autonomous-dev

### 9.2 Kreiraj initializer protocol
File: skills/initializer-protocol/SKILL.md

### 9.3 Azuriraj auto.md
Dodaj opciju za two-agent mode.

Kriterij zavrsetka Faze 9:
- references/two-agent-pattern.md postoji

---

## FAZA 10: INTEGRATION AND TESTING

### 10.1-10.5 Testiranje svih patterna
- Test feature list pattern
- Test result filtering
- Test QA agent
- Test progressive loading
- Full workflow test

Kriterij zavrsetka Faze 10:
- Sve prethodne faze complete u progress fileu

---

## PROGRESS TRACKING

Na pocetku SVAKE iteracije:
1. Citaj .claude/ralph-anthropic-progress.yaml
2. Identificiraj prvu nezavrsenu fazu
3. Radi na toj fazi
4. Azuriraj progress file
5. Verificiraj promjene

Progress file format (YAML):
- current_phase: broj
- phases: mapa 1-10 sa statusom pending/in_progress/complete
- last_iteration: broj
- last_action: opis
- improvements_made: broj

---

## COMPLETION CRITERIA

SAMO izjavi ANTHROPIC_PATTERNS_COMPLETE kada:

1. SVE 10 faza su complete
2. Feature list pattern implementiran
3. Result filtering aktivan u svim agentima
4. QA agent kreiran i integriran
5. Progressive skill loading konfiguriran
6. Examples dodani svim skillovima (min 3 po skillu)
7. PII tokenizer kreiran
8. E2E validator kreiran
9. Svi testovi prolaze

---

## SELF-CORRECTION

Ako naidjes na problem koji ne mozes rijesiti:
1. Dokumentiraj problem u .claude/ralph-blockers.md
2. Nastavi s drugim zadacima
3. Vrati se na blocker nakon 5 iteracija
4. Ako i dalje blokiran - eskaliraj u outputu

---

## ITERACIJA ZAPOCINJE SADA

1. Citaj trenutni progress iz .claude/ralph-anthropic-progress.yaml
2. Ako ne postoji, kreiraj ga i pocni od Faze 1
3. Pronadi prvi nezavrsen task
4. Napravi konkretnu promjenu
5. Verificiraj promjenu
6. Azuriraj progress
7. Output sto si napravio

NEMOJ output ANTHROPIC_PATTERNS_COMPLETE dok SVE nije gotovo!

---

## FALLBACK INSTRUKCIJE

Ako nakon 50 iteracija nisi zavrsio:
1. Napisi summary svega sto je napravljeno
2. Lista remaining issues
3. Output: PARTIAL_COMPLETION

Ako naidjes na fatal error:
1. Dokumentiraj error
2. Pokusaj recovery
3. Ako ne uspije: output FATAL_ERROR

---

Zapocni sada. Prva iteracija: provjeri postoji li progress file, ako ne - kreiraj ga i zapocni Fazu 1.
