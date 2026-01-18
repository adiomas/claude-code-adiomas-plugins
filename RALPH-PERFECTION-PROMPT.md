# Ralph Perfection Prompt za autonomous-dev Plugin

## Korištenje

```bash
/ralph-loop "$(cat RALPH-PERFECTION-PROMPT.md)" --max-iterations 100 --completion-promise "PERFECTION_ACHIEVED"
```

---

# AUTONOMOUS-DEV PLUGIN PERFECTION MISSION

Ti si Ralph - neumorni perfekcionista. Tvoja misija je dovesti autonomous-dev plugin do **apsolutnog savršenstva**. Radiš iterativno - svaka iteracija poboljšava plugin dok svi kriteriji ne budu ispunjeni.

## KRITIČNA PRAVILA

1. **NIKAD ne izjavi PERFECTION_ACHIEVED** dok SVE nije riješeno
2. **Svaka iteracija mora napraviti konkretnu promjenu** - čitaj, analiziraj, popravi, verificiraj
3. **Prati progress** u `.claude/ralph-progress.yaml`
4. **Koristi TodoWrite** za tracking svih zadataka
5. **Testiraj svaku promjenu** - pokreni `./scripts/validate-plugin.sh`

## FAZE POBOLJŠANJA

Prolazi kroz faze sekvencijalno. Faza je završena tek kada SVI njeni kriteriji prolaze.

---

## FAZA 1: STRUKTURALNA ISPRAVNOST

### 1.1 Plugin Manifest Validacija
- [ ] `.claude-plugin/plugin.json` ima sve obavezne polja
- [ ] `version` prati semver (X.Y.Z)
- [ ] `description` je jasan i koncizan
- [ ] `author` ima name i email
- [ ] `keywords` pokriva sve relevantne pojmove
- [ ] Dodaj `license`, `homepage`, `repository` polja

### 1.2 Strukturalna Konzistentnost
- [ ] Svi skill direktoriji imaju `SKILL.md`
- [ ] Svi skill-ovi imaju `references/` direktorij
- [ ] Svi agenti imaju `model:` i `color:` u frontmatter
- [ ] Svi agenti imaju `<example>` blokove u description
- [ ] Sve komande imaju `description` u frontmatter
- [ ] hooks.json koristi `${CLAUDE_PLUGIN_ROOT}` za portabilnost

### 1.3 Datotečne Provjere
Pokreni i popravi sve greške:
```bash
./scripts/validate-plugin.sh
```

**Kriterij završetka Faze 1:**
```bash
./scripts/validate-plugin.sh && echo "PHASE_1_COMPLETE"
# Output mora biti: "Plugin validation PASSED"
```

---

## FAZA 2: SHELL SCRIPT ROBUSTNOST

### 2.1 Error Handling
Za SVAKI `.sh` file:
- [ ] Ima `set -euo pipefail` na vrhu
- [ ] Sve varijable su quoted (`"$VAR"` umjesto `$VAR`)
- [ ] Koristi `${VAR:-default}` za optional varijable
- [ ] Ima graceful fallback za missing dependencies
- [ ] NE koristi `bc` - koristi pure bash aritmetiku ili awk

### 2.2 Cross-Platform Kompatibilnost
- [ ] Zamijeni macOS-specific komande (npr. `date -u` syntax)
- [ ] Zamijeni GNU-specific flags koji ne rade na BSD
- [ ] Dodaj detekciju OS-a gdje je potrebno
- [ ] Testiraj na macOS syntax

### 2.3 Dependency Management
- [ ] `detect-project.sh` - graceful fallback ako yq/jq nisu instalirani
- [ ] Dodaj installation hints za sve dependencies
- [ ] Kreiraj `scripts/check-dependencies.sh` koji provjerava sve

### 2.4 Security Hardening
- [ ] Sanitiziraj sve user inputs
- [ ] Izbjegavaj `eval` - koristi arrays
- [ ] Quote sve paths koji mogu imati spaces
- [ ] Ne koristi `$()` unutar double quotes bez escape-a

**Kriterij završetka Faze 2:**
```bash
shellcheck scripts/*.sh hooks/*.sh 2>&1 | grep -c "error:" | grep "^0$"
```

---

## FAZA 3: SKILL KVALITETA

### 3.1 Trigger Phrases
SVAKI skill MORA imati "This skill should be used when..." u description:
- [ ] project-detector
- [ ] work-type-classifier
- [ ] task-decomposer
- [ ] parallel-orchestrator
- [ ] verification-runner
- [ ] conflict-resolver
- [ ] mutation-tester

### 3.2 Reference Kompletnost
Svaki skill treba comprehensive references:
- [ ] project-detector/references/ - dodaj sve podržane frameworke
- [ ] work-type-classifier/references/ - dodaj keyword dictionary
- [ ] mutation-tester/references/ - dodaj troubleshooting guide

### 3.3 Skill Dokumentacija
- [ ] Svaki SKILL.md ima jasne korake (Step 1, Step 2...)
- [ ] Svaki SKILL.md ima primjere korištenja
- [ ] Svaki SKILL.md ima "Quality Standards" sekciju
- [ ] Svaki SKILL.md ima "When NOT to use" sekciju

**Kriterij završetka Faze 3:**
```bash
grep -r "This skill should be used when" skills/*/SKILL.md | wc -l
# Mora biti >= 7 (jedan za svaki skill)
```

---

## FAZA 4: AGENT POBOLJŠANJA

### 4.1 Agent Descriptions
Svaki agent MORA imati:
- [ ] Jasan `description` s trigger phrases
- [ ] Minimalno 2 `<example>` bloka
- [ ] `<commentary>` u svakom example-u
- [ ] `model:` field (inherit, haiku, sonnet, opus)
- [ ] `color:` field
- [ ] `tools:` lista

### 4.2 Agent Improvements
- [ ] task-executor - dodaj timeout handling
- [ ] integration-validator - dodaj conflict visualization
- [ ] schema-validator - dodaj support za non-Supabase DBs
- [ ] code-reviewer - dodaj security-focused mode
- [ ] verification-agent - dodaj parallel verification

**Kriterij završetka Faze 4:**
```bash
for f in agents/*.md; do
  grep -q "<example>" "$f" && grep -q "model:" "$f" && grep -q "color:" "$f"
done && echo "AGENTS_VALID"
```

---

## FAZA 5: COMMAND POBOLJŠANJA

### 5.1 Frontmatter Kompletnost
Svaka komanda treba:
- [ ] `description` - kratki opis (max 100 chars)
- [ ] `argument-hint` - primjer argumenta
- [ ] `allowed-tools` - lista dozvoljenih tool-a

### 5.2 Command Documentation
- [ ] auto.md - dodaj troubleshooting sekciju
- [ ] auto-lite.md - jasno definiraj kada koristiti vs /auto
- [ ] auto-audit.md - dodaj primjere audit tipova
- [ ] auto-continue.md - objasni checkpoint sistem

### 5.3 New Commands (ako nedostaju)
- [ ] Dodaj `/auto-config` - za konfiguraciju plugin-a
- [ ] Dodaj `/auto-clean` - za čišćenje worktrees/state

**Kriterij završetka Faze 5:**
```bash
grep -l "argument-hint" commands/*.md | wc -l
# Trebalo bi biti >= 6
```

---

## FAZA 6: HOOK OPTIMIZACIJA

### 6.1 Hook Efficiency
- [ ] Reduciraj timeout na post-tool.sh (60s -> 30s)
- [ ] Dodaj caching za česte operacije
- [ ] Implementiraj debouncing za Edit/Write hooks

### 6.2 Hook Coverage
- [ ] Dodaj PreToolUse hook za Bash (security check)
- [ ] Dodaj NotificationHook za completion
- [ ] Razmotriti SessionEnd hook za cleanup

### 6.3 Hook Error Handling
- [ ] Svi hooks moraju gracefully fail
- [ ] Nikad ne blokiraj user experience zbog hook error-a
- [ ] Logiraj errors u `.claude/hook-errors.log`

**Kriterij završetka Faze 6:**
```bash
jq '.hooks | keys' hooks/hooks.json
# Mora imati SessionStart, Stop, PostToolUse
```

---

## FAZA 7: DETEKCIJA I KLASIFIKACIJA

### 7.1 Framework Detection
Dodaj podršku za framework-e koji nedostaju:
- [ ] Remix (remix.config.js)
- [ ] Hono (hono u package.json)
- [ ] Elysia (elysia u package.json)
- [ ] tRPC detekcija
- [ ] Turborepo/monorepo detekcija
- [ ] NX workspace detekcija

### 7.2 Database Detection
Poboljšaj detekciju:
- [ ] Convex
- [ ] Turso
- [ ] Upstash Redis
- [ ] EdgeDB
- [ ] CockroachDB

### 7.3 Work Type Classifier
- [ ] Dodaj DEVOPS work type
- [ ] Dodaj MOBILE work type (React Native, Flutter)
- [ ] Poboljšaj confidence calculation
- [ ] Dodaj language detection (ne samo HR/EN)

**Kriterij završetka Faze 7:**
```bash
grep -c "framework" scripts/detect-project.sh
# Mora biti >= 15 (5 postojećih + 10 novih)
```

---

## FAZA 8: DOKUMENTACIJA

### 8.1 README.md
- [ ] Ažuriraj verziju na 3.1.0
- [ ] Dodaj badges (version, license)
- [ ] Dodaj GIF/screenshot workflow-a
- [ ] Dodaj Troubleshooting sekciju
- [ ] Dodaj FAQ sekciju
- [ ] Dodaj Contributing guide

### 8.2 Reference Dokumentacija
- [ ] Kreiraj `references/ARCHITECTURE.md` - objašnjenje arhitekture
- [ ] Kreiraj `references/TROUBLESHOOTING.md`
- [ ] Kreiraj `references/CHANGELOG.md`

### 8.3 Inline Komentari
- [ ] Dodaj komentare u sve shell scripte
- [ ] Dokumentiraj sve funkcije u scripts/

**Kriterij završetka Faze 8:**
```bash
test -f README.md && grep -q "Troubleshooting" README.md && echo "DOCS_VALID"
```

---

## FAZA 9: ERROR HANDLING & RECOVERY

### 9.1 Graceful Degradation
- [ ] Implementiraj fallback za svaku external dependency
- [ ] Dodaj retry logic (max 3) za network operacije
- [ ] Kreiraj recovery procedure za corrupted state

### 9.2 Error Logging
- [ ] Centraliziraj error logging u `.claude/errors.log`
- [ ] Dodaj timestamps i stack traces
- [ ] Implementiraj log rotation (max 1MB)

### 9.3 State Recovery
- [ ] Dodaj `scripts/recover-state.sh` za recovery
- [ ] Backup state files prije modifikacije
- [ ] Implementiraj rollback za failed operations

**Kriterij završetka Faze 9:**
```bash
test -f scripts/recover-state.sh && echo "RECOVERY_EXISTS"
```

---

## FAZA 10: PERFORMANCE & CLEANUP

### 10.1 Performance Optimization
- [ ] Cache project-profile.yaml rezultate (već postoji, verify radi)
- [ ] Lazy-load skills (samo kada su potrebni)
- [ ] Paralelizira nezavisne provjere

### 10.2 Cleanup Mechanisms
- [ ] Auto-cleanup worktrees starijih od 7 dana
- [ ] Clean stale state files
- [ ] Remove empty memory directories

### 10.3 Resource Management
- [ ] Limita broj paralelnih agenata (max 5)
- [ ] Monitor disk usage za worktrees
- [ ] Graceful handling large repos

**Kriterij završetka Faze 10:**
```bash
# Nema stale worktrees
ls /tmp/auto-worktrees 2>/dev/null | wc -l | grep -E "^[0-5]$"
```

---

## FAZA 11: TESTIRANJE

### 11.1 Unit Tests za Scripts
- [ ] Kreiraj `tests/` direktorij
- [ ] Test detect-project.sh sa različitim project tipovima
- [ ] Test state-transition.sh transitions
- [ ] Test token-monitor.sh thresholds

### 11.2 Integration Tests
- [ ] Test full /auto workflow na sample projektu
- [ ] Test /auto-continue resume
- [ ] Test parallel execution

### 11.3 Edge Case Tests
- [ ] Test s empty projektom
- [ ] Test s corrupted state
- [ ] Test s missing dependencies

**Kriterij završetka Faze 11:**
```bash
test -d tests && ls tests/*.sh 2>/dev/null | wc -l | grep -v "^0$"
```

---

## FAZA 12: FINAL VALIDATION

### 12.1 Full Plugin Validation
```bash
./scripts/validate-plugin.sh
# MORA output: "Plugin validation PASSED" s 0 errors
```

### 12.2 Shellcheck Clean
```bash
shellcheck scripts/*.sh hooks/*.sh 2>&1 | grep -c "error:"
# MORA biti 0
```

### 12.3 Documentation Complete
- [ ] README je up-to-date
- [ ] Sve skills imaju SKILL.md
- [ ] Svi agents imaju examples
- [ ] CHANGELOG postoji

### 12.4 Version Bump
- [ ] Ažuriraj version na 3.1.0 u plugin.json
- [ ] Ažuriraj version u README.md
- [ ] Ažuriraj version u auto-version.md

---

## PROGRESS TRACKING

Na početku SVAKE iteracije:
1. Čitaj `.claude/ralph-progress.yaml`
2. Identificiraj prvu nezavršenu fazu
3. Radi na toj fazi
4. Ažuriraj progress file
5. Verificiraj promjene

Progress file format:
```yaml
# .claude/ralph-progress.yaml
current_phase: 3
phases:
  1: complete
  2: complete
  3: in_progress
  4: pending
  # ...
  12: pending
last_iteration: 15
last_action: "Added trigger phrases to skills"
issues_fixed: 42
issues_remaining: 12
```

---

## COMPLETION CRITERIA

SAMO izjavi `<promise>PERFECTION_ACHIEVED</promise>` kada:

1. ✅ SVE 12 faza su complete
2. ✅ `./scripts/validate-plugin.sh` prolazi bez grešaka
3. ✅ `shellcheck scripts/*.sh hooks/*.sh` nema errors
4. ✅ Svih 7 skill-ova ima "This skill should be used when"
5. ✅ Svih 5 agenata ima `<example>` blokove
6. ✅ README.md ima Troubleshooting sekciju
7. ✅ Version je bumped na 3.1.0
8. ✅ `.claude/ralph-progress.yaml` pokazuje sve phases complete

---

## SELF-CORRECTION

Ako naiđeš na problem koji ne možeš riješiti:
1. Dokumentiraj problem u `.claude/ralph-blockers.md`
2. Nastavi s drugim zadacima
3. Vrati se na blocker nakon 5 iteracija
4. Ako i dalje blokiran - eskaliraj u outputu

Ako napraviš grešku:
1. NE PANIČARI
2. `git diff` da vidiš što si promijenio
3. `git checkout -- <file>` ako treba rollback
4. Nastavi s ispravnom verzijom

---

## ITERACIJA ZAPOČINJE SADA

1. Čitaj trenutni progress iz `.claude/ralph-progress.yaml`
2. Ako ne postoji, kreiraj ga i počni od Faze 1
3. Pronađi prvi nezavršen task
4. Napravi konkretnu promjenu
5. Verificiraj promjenu
6. Ažuriraj progress
7. Output što si napravio

**NEMOJ output `<promise>PERFECTION_ACHIEVED</promise>` dok SVE nije gotovo!**

---

## FALLBACK INSTRUKCIJE

Ako nakon 50 iteracija nisi završio:
1. Napiši summary svega što je napravljeno
2. Lista remaining issues
3. Output: `<promise>PARTIAL_COMPLETION</promise>`

Ako naiđeš na fatal error:
1. Dokumentiraj error
2. Pokušaj recovery
3. Ako ne uspije: output `<promise>FATAL_ERROR</promise>`

---

Započni sada. Prva iteracija: provjeri postoji li progress file, ako ne - kreiraj ga i započni Fazu 1.
