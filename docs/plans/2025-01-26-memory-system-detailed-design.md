# Memory System - Detailed Design

**Parent:** AGI-Like Interface Design
**Status:** Approved
**Date:** 2025-01-26

## Overview

Hibridni memory system koji omogućuje učenje iz iskustva - lokalno (projekt-specifično) i globalno (dijeljeno između projekata).

```
┌─────────────────────────────────────────────────────────────────┐
│                      MEMORY SYSTEM                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ~/.claude/global-memory/          <projekt>/.claude/memory/   │
│   ┌───────────────────────┐        ┌───────────────────────┐   │
│   │   GLOBAL MEMORY       │        │    LOCAL MEMORY       │   │
│   │                       │        │                       │   │
│   │ • Patterns by domain  │        │ • Project context     │   │
│   │ • Gotchas by tech     │        │ • Recent sessions     │   │
│   │ • User preferences    │        │ • Project learnings   │   │
│   │                       │        │                       │   │
│   │ Retention: Forever    │        │ Retention: 90 days    │   │
│   │ (with cleanup)        │        │                       │   │
│   └───────────────────────┘        └───────────────────────┘   │
│                                                                 │
│                    ┌─────────────────┐                          │
│                    │ CONFLICT RESOLVER│                         │
│                    │                 │                          │
│                    │ Confidence-based│                          │
│                    │ resolution      │                          │
│                    └─────────────────┘                          │
│                                                                 │
│                    ┌─────────────────┐                          │
│                    │    LEARNER      │                          │
│                    │                 │                          │
│                    │ Extract patterns│                          │
│                    │ from success    │                          │
│                    └─────────────────┘                          │
│                                                                 │
│                    ┌─────────────────┐                          │
│                    │   FORGETTER     │                          │
│                    │                 │                          │
│                    │ Decay + feedback│                          │
│                    │ + failure-based │                          │
│                    └─────────────────┘                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. Storage Structure

### Global Memory (`~/.claude/global-memory/`)

```
~/.claude/global-memory/
├── index.json                    # Quick lookup index
│
├── patterns/                     # Patterns by domain
│   ├── auth.yaml                 # Authentication patterns
│   ├── api.yaml                  # API design patterns
│   ├── database.yaml             # Database patterns
│   ├── ui.yaml                   # UI/UX patterns
│   ├── testing.yaml              # Testing patterns
│   └── error-handling.yaml       # Error handling patterns
│
├── gotchas/                      # Gotchas by technology
│   ├── react.yaml
│   ├── nextjs.yaml
│   ├── typescript.yaml
│   ├── supabase.yaml
│   ├── vitest.yaml
│   └── prisma.yaml
│
├── preferences.yaml              # User preferences
│
└── stats.yaml                    # Usage statistics for cleanup
```

### Local Memory (`<projekt>/.claude/memory/`)

```
<projekt>/.claude/memory/
├── project-context.yaml          # Project-specific context
├── sessions/                     # Session history
│   ├── 2025-01-25.yaml
│   ├── 2025-01-26.yaml
│   └── ...
├── learnings.yaml                # Project-specific learnings
└── references.yaml               # Quick references to past work
```

---

## 2. Data Schemas

### Pattern Schema (Global)

```yaml
# ~/.claude/global-memory/patterns/auth.yaml

domain: authentication
patterns:
  - id: "auth-password-hashing"
    name: "Password Hashing"
    description: "Secure password hashing approach"
    approach: |
      1. Use bcrypt with cost factor 12
      2. Never store plain passwords
      3. Use constant-time comparison
    code_example: |
      import bcrypt from 'bcrypt';
      const hash = await bcrypt.hash(password, 12);
      const valid = await bcrypt.compare(input, hash);
    applicable_when:
      - "password"
      - "user registration"
      - "login"
    confidence: 0.95
    learned_from:
      - project: "saas-app"
        date: "2025-01-10"
        success: true
      - project: "ecommerce"
        date: "2025-01-20"
        success: true
    last_used: "2025-01-25"
    use_count: 12

  - id: "auth-jwt-tokens"
    name: "JWT Token Strategy"
    description: "JWT for stateless authentication"
    approach: |
      1. Access token: 15 min expiry
      2. Refresh token: 7 days, rotate on use
      3. Store in httpOnly cookies (not localStorage)
    confidence: 0.88
    learned_from:
      - project: "saas-app"
        date: "2025-01-15"
        success: true
    alternatives:
      - name: "Session-based"
        when: "Server-rendered apps, need instant revocation"
      - name: "Longer expiry"
        when: "Low-security apps, better UX"
    last_used: "2025-01-24"
    use_count: 8
```

### Gotcha Schema (Global)

```yaml
# ~/.claude/global-memory/gotchas/vitest.yaml

technology: vitest
gotchas:
  - id: "vitest-localstorage-mock"
    title: "localStorage Mock"
    problem: "localStorage is undefined in test environment"
    solution: |
      Use vi.stubGlobal instead of jest.mock:

      ```typescript
      const mockStorage = {
        getItem: vi.fn(),
        setItem: vi.fn(),
        clear: vi.fn(),
      };
      vi.stubGlobal('localStorage', mockStorage);
      ```
    wrong_approach: "Using jest.mock('localStorage')"
    confidence: 0.92
    learned_from:
      - project: "dashboard-app"
        date: "2025-01-22"
        error_encountered: "ReferenceError: localStorage is not defined"
    tags: ["testing", "mocking", "browser-apis"]
    last_used: "2025-01-25"

  - id: "vitest-async-cleanup"
    title: "Async Test Cleanup"
    problem: "Tests fail intermittently due to async cleanup"
    solution: |
      Always await cleanup in afterEach:

      ```typescript
      afterEach(async () => {
        await cleanup();
        vi.clearAllMocks();
      });
      ```
    confidence: 0.85
    learned_from:
      - project: "api-client"
        date: "2025-01-18"
```

### Preferences Schema (Global)

```yaml
# ~/.claude/global-memory/preferences.yaml

code_style:
  paradigm: "functional-preferred"  # functional-preferred | oop-preferred | mixed
  comments: "minimal"               # minimal | moderate | verbose
  naming: "descriptive"             # short | descriptive | verbose

testing:
  style: "integration-first"        # unit-first | integration-first | e2e-first
  coverage_target: 80
  framework_preference: "vitest"    # vitest | jest | mocha

git:
  commit_style: "conventional"      # conventional | freeform
  branch_naming: "feature/kebab-case"

formatting:
  indent: 2
  quotes: "single"
  semicolons: false

updated_at: "2025-01-26T10:00:00Z"
```

### Project Context Schema (Local)

```yaml
# <projekt>/.claude/memory/project-context.yaml

project:
  name: "my-saas-app"
  type: "fullstack"
  created_detected: "2025-01-20"

stack:
  language: "typescript"
  framework: "nextjs"
  version: "14.1"
  runtime: "node"
  package_manager: "pnpm"

database:
  provider: "supabase"
  orm: null  # Using Supabase client directly

testing:
  framework: "vitest"
  e2e: "playwright"

commands:
  dev: "pnpm dev"
  test: "pnpm test"
  build: "pnpm build"
  lint: "pnpm lint"
  typecheck: "pnpm typecheck"

quirks:
  - description: "Async Supabase client - always await"
    applies_to: ["src/lib/supabase.ts", "src/api/**"]
    learned: "2025-01-21"

  - description: "CSS modules, not direct Tailwind in JSX"
    applies_to: ["src/components/**"]
    learned: "2025-01-22"

  - description: "Environment variables need NEXT_PUBLIC_ prefix for client"
    applies_to: ["*.tsx", "*.ts"]
    learned: "2025-01-23"

conventions:
  file_naming: "kebab-case"
  component_style: "functional"
  state_management: "react-query + zustand"
```

### Session Schema (Local)

```yaml
# <projekt>/.claude/memory/sessions/2025-01-25.yaml

date: "2025-01-25"
sessions:
  - id: "session-001"
    started_at: "2025-01-25T09:00:00Z"
    ended_at: "2025-01-25T11:30:00Z"

    task:
      input: "Implement Google OAuth authentication"
      type: "FEATURE"
      complexity: 4

    outcome:
      status: "success"
      files_created:
        - "src/auth/google.ts"
        - "src/auth/google.test.ts"
        - "src/components/GoogleLoginButton.tsx"
      files_modified:
        - "src/middleware.ts"
        - "src/app/api/auth/[...nextauth]/route.ts"

    decisions:
      - question: "Token storage"
        decision: "httpOnly cookies"
        reason: "Security - prevents XSS access"

      - question: "Session duration"
        decision: "24 hours with refresh"
        reason: "Balance between security and UX"

    learnings:
      - type: "pattern"
        content: "NextAuth.js Google provider setup"
        promote_to_global: true

      - type: "gotcha"
        content: "GOOGLE_CLIENT_ID needs to be in .env.local, not .env"
        promote_to_global: false  # Next.js specific

    verification:
      tests: "12/12 passed"
      build: "success"
      manual: "OAuth flow verified in browser"
```

---

## 3. Learning Pipeline

### When Learning Happens

```python
def on_task_complete(task: Task, result: TaskResult):
    """Triggered when a task completes successfully."""

    # Only learn from verified success
    if not result.verified:
        return

    # Extract learnings
    learnings = extract_learnings(task, result)

    for learning in learnings:
        # Determine storage location
        if should_promote_to_global(learning):
            store_global(learning)
        else:
            store_local(learning)
```

### Learning Extraction

```python
def extract_learnings(task: Task, result: TaskResult) -> List[Learning]:
    """Extract patterns, gotchas, and preferences from completed task."""

    learnings = []

    # 1. Pattern extraction
    if task.type in ["FEATURE", "REFACTOR"]:
        patterns = extract_patterns(task, result)
        learnings.extend(patterns)

    # 2. Gotcha extraction (from errors encountered and solved)
    if result.errors_encountered:
        gotchas = extract_gotchas(result.errors_encountered, result.solutions)
        learnings.extend(gotchas)

    # 3. Decision extraction
    if task.decisions:
        decisions = extract_decisions(task.decisions)
        learnings.extend(decisions)

    # 4. Quirk extraction (project-specific)
    quirks = extract_quirks(task, result)
    learnings.extend(quirks)

    return learnings
```

### Global Promotion Criteria

```python
def should_promote_to_global(learning: Learning) -> bool:
    """Determine if learning should be stored globally."""

    # Technology-agnostic patterns → global
    if learning.type == "pattern" and not learning.tech_specific:
        return True

    # Gotchas for common technologies → global
    COMMON_TECH = ["react", "typescript", "node", "python", "git"]
    if learning.type == "gotcha" and learning.technology in COMMON_TECH:
        return True

    # User explicitly marked for global
    if learning.promote_to_global:
        return True

    # Project-specific quirks → local only
    if learning.type == "quirk":
        return False

    # Default: local
    return False
```

### Success-Based Validation

```python
def validate_before_storing(learning: Learning) -> bool:
    """Only store learnings from verified successful tasks."""

    # Must have verification evidence
    if not learning.source_task.verification:
        return False

    # Verification must have passed
    if not learning.source_task.verification.all_passed:
        return False

    # For patterns: must have been applied successfully
    if learning.type == "pattern":
        if not learning.was_applied_successfully:
            return False

    # For gotchas: must have actually solved the problem
    if learning.type == "gotcha":
        if not learning.solution_verified:
            return False

    return True
```

---

## 4. Conflict Resolution

### Confidence-Based Resolution

```python
def resolve_conflict(local: Knowledge, global_: Knowledge, context: Context) -> Knowledge:
    """Resolve conflict between local and global knowledge."""

    # Calculate effective confidence with context boost
    local_conf = calculate_effective_confidence(local, context)
    global_conf = calculate_effective_confidence(global_, context)

    # Winner takes all
    if local_conf > global_conf:
        winner = local
        log_resolution("local", local_conf, global_conf)
    else:
        winner = global_
        log_resolution("global", global_conf, local_conf)

    return winner

def calculate_effective_confidence(knowledge: Knowledge, context: Context) -> float:
    """Calculate confidence with context-based adjustments."""

    base = knowledge.confidence

    # Recency boost (used recently = more relevant)
    days_since_use = (now() - knowledge.last_used).days
    recency_factor = max(0.8, 1.0 - (days_since_use * 0.01))

    # Frequency boost (used often = more reliable)
    frequency_factor = min(1.2, 1.0 + (knowledge.use_count * 0.02))

    # Context match boost (matches current project stack)
    context_factor = 1.0
    if knowledge.technology and knowledge.technology in context.stack:
        context_factor = 1.15

    # Success rate factor
    success_factor = knowledge.success_rate if hasattr(knowledge, 'success_rate') else 1.0

    return base * recency_factor * frequency_factor * context_factor * success_factor
```

### Conflict Examples

```yaml
# Example 1: Testing framework conflict
global:
  knowledge: "Use Jest for testing"
  confidence: 0.85
  use_count: 20
  last_used: "2025-01-20"

local:
  knowledge: "This project uses Vitest"
  confidence: 0.95
  use_count: 5
  last_used: "2025-01-26"

context:
  stack: ["vitest", "react", "typescript"]

resolution:
  winner: local
  reason: |
    Local confidence (0.95) > Global (0.85)
    Plus: local matches current stack (vitest in context)
    Effective: local=1.09, global=0.82

# Example 2: Pattern conflict
global:
  knowledge: "bcrypt with cost 12"
  confidence: 0.95
  use_count: 50
  success_rate: 1.0

local:
  knowledge: "argon2 for this security-critical app"
  confidence: 0.70
  use_count: 1

resolution:
  winner: global
  reason: |
    Global has much higher confidence and success rate
    Local is new and unproven
    Suggest: "Global says bcrypt. You used argon2 once here. Continue with argon2?"
```

---

## 5. Forgetting System

### Multi-Strategy Cleanup

```python
class Forgetter:
    """Manages knowledge cleanup through multiple strategies."""

    def run_cleanup(self):
        """Run all cleanup strategies."""

        # Strategy 1: Time-based decay
        self.apply_time_decay()

        # Strategy 2: Failure-based reduction
        self.apply_failure_penalties()

        # Strategy 3: Process explicit feedback
        self.process_user_feedback()

        # Strategy 4: Remove below threshold
        self.remove_low_confidence()
```

### Time-Based Decay

```python
def apply_time_decay(self):
    """Reduce confidence for unused knowledge."""

    for knowledge in self.all_knowledge():
        days_unused = (now() - knowledge.last_used).days

        # No decay for first 30 days
        if days_unused <= 30:
            continue

        # Gradual decay after 30 days
        # Lose ~0.5% confidence per day of non-use
        decay_days = days_unused - 30
        decay_factor = 0.995 ** decay_days

        knowledge.confidence *= decay_factor

        # Floor at 0.1 (don't go to zero from decay alone)
        knowledge.confidence = max(0.1, knowledge.confidence)
```

### Failure-Based Reduction

```python
def apply_failure_penalties(self):
    """Reduce confidence when knowledge leads to failures."""

    for failure in self.recent_failures():
        # Find knowledge that was used
        used_knowledge = failure.knowledge_applied

        for knowledge in used_knowledge:
            # Penalty based on failure severity
            if failure.severity == "HIGH":
                penalty = 0.15
            elif failure.severity == "MEDIUM":
                penalty = 0.10
            else:
                penalty = 0.05

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

### User Feedback Processing

```python
def process_user_feedback(self):
    """Handle explicit user corrections."""

    for feedback in self.pending_feedback():
        knowledge = self.get_knowledge(feedback.knowledge_id)

        if feedback.type == "INCORRECT":
            # Major penalty
            knowledge.confidence -= 0.3
            knowledge.notes.append({
                "type": "user_correction",
                "date": now(),
                "feedback": feedback.comment
            })

        elif feedback.type == "OUTDATED":
            # Mark for review
            knowledge.needs_review = True
            knowledge.confidence -= 0.2

        elif feedback.type == "FORGET":
            # User explicitly wants to remove
            self.archive_knowledge(knowledge)

        elif feedback.type == "CONFIRM":
            # User confirms it's correct
            knowledge.confidence = min(1.0, knowledge.confidence + 0.1)
            knowledge.last_confirmed = now()
```

### Removal Threshold

```python
def remove_low_confidence(self):
    """Remove knowledge below threshold."""

    THRESHOLD = 0.3

    for knowledge in self.all_knowledge():
        if knowledge.confidence < THRESHOLD:
            # Archive, don't delete (can be recovered)
            self.archive_knowledge(knowledge)

            log_removal(
                knowledge_id=knowledge.id,
                final_confidence=knowledge.confidence,
                reason="below_threshold",
                archived_to=f"archive/{knowledge.id}.yaml"
            )
```

### Cleanup Schedule

```yaml
# Cleanup runs automatically

schedules:
  time_decay:
    frequency: "daily"
    runs_at: "03:00"  # Low activity time

  failure_processing:
    frequency: "on_failure"  # Immediate

  user_feedback:
    frequency: "immediate"  # As soon as received

  threshold_removal:
    frequency: "weekly"
    runs_at: "Sunday 04:00"

  archive_cleanup:
    frequency: "monthly"
    description: "Remove archived items older than 6 months"
```

---

## 6. Memory API

### Read Operations

```python
class MemoryAPI:

    def get_relevant(self, intent: EnrichedIntent) -> MemoryContext:
        """Get all relevant knowledge for an intent."""

        return MemoryContext(
            patterns=self.find_patterns(intent),
            gotchas=self.find_gotchas(intent),
            similar_tasks=self.find_similar_tasks(intent),
            project_quirks=self.get_project_quirks(),
            preferences=self.get_preferences()
        )

    def find_patterns(self, intent: EnrichedIntent) -> List[Pattern]:
        """Find applicable patterns."""

        # Search by domain
        domain_patterns = self.global_memory.patterns.get(intent.domain)

        # Search by keywords
        keyword_patterns = self.search_patterns(intent.keywords)

        # Combine and rank by confidence
        all_patterns = domain_patterns + keyword_patterns
        return sorted(all_patterns, key=lambda p: p.confidence, reverse=True)

    def find_similar_tasks(self, intent: EnrichedIntent, limit=5) -> List[PastTask]:
        """Find similar past tasks using embeddings."""

        intent_embedding = get_embedding(intent.raw_input)

        similar = []
        for session in self.local_memory.sessions:
            for task in session.tasks:
                task_embedding = get_embedding(task.input)
                similarity = cosine_similarity(intent_embedding, task_embedding)

                if similarity > 0.7:
                    similar.append((task, similarity))

        # Sort by similarity and return top N
        similar.sort(key=lambda x: x[1], reverse=True)
        return [task for task, _ in similar[:limit]]
```

### Write Operations

```python
class MemoryAPI:

    def store_learning(self, learning: Learning):
        """Store a new learning."""

        # Validate
        if not validate_before_storing(learning):
            return

        # Determine location
        if should_promote_to_global(learning):
            self._store_global(learning)
        else:
            self._store_local(learning)

    def update_confidence(self, knowledge_id: str, delta: float, reason: str):
        """Update confidence score."""

        knowledge = self.get(knowledge_id)
        knowledge.confidence = max(0, min(1, knowledge.confidence + delta))
        knowledge.history.append({
            "type": "confidence_update",
            "delta": delta,
            "reason": reason,
            "timestamp": now()
        })
        self.save(knowledge)

    def record_usage(self, knowledge_id: str, success: bool, context: dict):
        """Record that knowledge was used."""

        knowledge = self.get(knowledge_id)
        knowledge.use_count += 1
        knowledge.last_used = now()

        if success:
            # Small confidence boost for successful use
            knowledge.confidence = min(1.0, knowledge.confidence + 0.01)
        else:
            # Record failure
            knowledge.failure_count += 1
            knowledge.confidence -= 0.05

        self.save(knowledge)
```

---

## 7. File Locations Summary

```
~/.claude/global-memory/              # Global (shared across projects)
├── index.json                        # Quick lookup
├── patterns/                         # By domain
│   ├── auth.yaml
│   ├── api.yaml
│   └── ...
├── gotchas/                          # By technology
│   ├── react.yaml
│   ├── vitest.yaml
│   └── ...
├── preferences.yaml                  # User preferences
├── stats.yaml                        # Usage statistics
└── archive/                          # Archived (forgotten) knowledge

<project>/.claude/memory/             # Local (project-specific)
├── project-context.yaml              # Project detection results
├── learnings.yaml                    # Project-specific learnings
├── references.yaml                   # Quick refs to past work
└── sessions/                         # Session history
    ├── 2025-01-25.yaml
    └── ...
```

---

## 8. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Pattern hit rate | >60% | Tasks using stored patterns |
| Gotcha prevention | >80% | Known gotchas avoided |
| Conflict resolution accuracy | >90% | Correct winner chosen |
| Memory size | <10MB local, <50MB global | Storage efficiency |
| Cleanup effectiveness | <5% stale data | Old unused data removed |
| Learning extraction | >3 learnings/session | Knowledge captured |
