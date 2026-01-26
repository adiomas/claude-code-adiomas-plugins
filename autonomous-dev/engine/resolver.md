# Intent Resolver

Resolves ambiguity and detects critical actions that require user confirmation.

## When to Use

- After Classifier produces ClassifiedIntent
- Before Strategist selects execution strategy

## What It Does

```
Classified Intent
      │
      ▼
┌─────────────────────────────────────────────┐
│              RESOLVER                        │
├─────────────────────────────────────────────┤
│                                             │
│  1. Detect Critical Actions                 │
│     → Deletion, security, DB changes        │
│                                             │
│  2. Check Confidence Level                  │
│     → < 0.7 = ambiguous                     │
│                                             │
│  3. Decide Action                           │
│     → PROCEED / ASK_CHOICE / ASK_OPEN       │
│                                             │
│  4. Format Question (if needed)             │
│     → Clear, actionable options             │
│                                             │
└─────────────────────────────────────────────┘
      │
      ▼
Resolution (PROCEED or ASK)
```

## Resolution Types

| Type | When | Action |
|------|------|--------|
| PROCEED | Confident + no critical actions | Continue autonomously |
| ASK_CHOICE | Ambiguous with ≤3 interpretations | Show options |
| ASK_OPEN | Very ambiguous or critical | Open question |
| BLOCK | Extremely critical (destructive) | Require explicit confirmation |

## Decision Algorithm

```python
def resolve(intent: ClassifiedIntent) -> Resolution:
    """Decide whether to proceed autonomously or ask user."""

    # Check for critical actions first
    critical = detect_critical_actions(intent)

    if critical:
        highest_severity = max(c.severity for c in critical)

        if highest_severity == "EXTREME":
            return Resolution(
                action="BLOCK",
                reason="extreme_critical",
                question=format_block_question(critical),
                requires_explicit="yes"
            )

        if highest_severity == "HIGH":
            return Resolution(
                action="ASK",
                reason="critical_action",
                question=format_critical_question(critical)
            )

    # Check confidence level
    if intent.confidence < 0.7:
        interpretations = generate_interpretations(intent)

        if len(interpretations) <= 3:
            return Resolution(
                action="ASK_CHOICE",
                reason="low_confidence",
                options=interpretations
            )
        else:
            return Resolution(
                action="ASK_OPEN",
                reason="very_ambiguous",
                question="Nisam siguran što misliš. Možeš li pojasniti?"
            )

    # Confident and not critical → proceed
    return Resolution(action="PROCEED")
```

## Critical Actions Detection

### Severity Levels

| Level | Actions | Confirmation |
|-------|---------|--------------|
| EXTREME | rm -rf, DROP DATABASE, delete prod | Type "yes" to confirm |
| HIGH | delete files, modify auth, schema changes | Simple confirm |
| MEDIUM | major deps upgrade, API breaking changes | Quick confirm |
| LOW | minor potentially breaking changes | No confirmation |

### Detection Patterns

```python
CRITICAL_PATTERNS = {
    "deletion": {
        "patterns": [
            r"\bdelete\b", r"\bremove\b", r"\bobriši\b",
            r"\brm\b", r"\bunlink\b", r"\bdrop\b"
        ],
        "exceptions": ["node_modules", ".cache", "build/", "dist/"],
        "severity": "HIGH",
        "severity_extreme_if": [r"rm\s+-rf", r"all files", r"everything"]
    },

    "security": {
        "patterns": [
            r"\bauth\b", r"\bpassword\b", r"\btoken\b",
            r"\bsecret\b", r"\bpermission\b", r"\bcredential\b"
        ],
        "context_required": ["change", "modify", "update", "remove", "delete"],
        "severity": "HIGH"
    },

    "database": {
        "patterns": [
            r"\bmigration\b", r"\bschema\b", r"\bdrop\b",
            r"\balter\b", r"\btruncate\b"
        ],
        "severity": "HIGH",
        "severity_extreme_if": [r"drop.*table", r"truncate", r"delete.*all"]
    },

    "api_breaking": {
        "patterns": [
            r"\brename endpoint\b", r"\bremove parameter\b",
            r"\bchange response\b", r"\bbreaking change\b"
        ],
        "severity": "MEDIUM"
    },

    "dependencies": {
        "patterns": [
            r"\bupgrade\b.*\bmajor\b", r"\breplace\b.*\bwith\b",
            r"\bmigrate from\b"
        ],
        "severity": "MEDIUM"
    },

    "production": {
        "patterns": [
            r"\bprod\b", r"\bproduction\b", r"\blive\b"
        ],
        "context_required": ["deploy", "push", "change", "update"],
        "severity": "HIGH"
    }
}


def detect_critical_actions(intent: ClassifiedIntent) -> List[CriticalAction]:
    """Detect all critical actions in intent."""

    critical = []
    text = intent.raw_input.lower()

    for category, config in CRITICAL_PATTERNS.items():
        for pattern in config["patterns"]:
            if re.search(pattern, text):
                # Check exceptions
                if any(exc in text for exc in config.get("exceptions", [])):
                    continue

                # Check context requirement
                if "context_required" in config:
                    if not any(ctx in text for ctx in config["context_required"]):
                        continue

                # Determine severity
                severity = config["severity"]

                # Check for extreme conditions
                if "severity_extreme_if" in config:
                    for extreme_pattern in config["severity_extreme_if"]:
                        if re.search(extreme_pattern, text):
                            severity = "EXTREME"
                            break

                critical.append(CriticalAction(
                    category=category,
                    severity=severity,
                    matched=pattern,
                    text_context=extract_context(text, pattern)
                ))

    return critical
```

## Question Formatting

### Critical Action Question

```python
def format_critical_question(critical: List[CriticalAction]) -> str:
    """Format question for critical actions."""

    if len(critical) == 1:
        c = critical[0]
        return TEMPLATES[c.category].format(
            action=c.matched,
            severity=c.severity,
            context=c.text_context
        )

    # Multiple critical actions
    items = "\n".join(f"• {c.category}: {c.text_context}" for c in critical)

    return f"""KRITIČNE AKCIJE DETEKTIRANE

Ova operacija uključuje:
{items}

Želiš nastaviti? [Da] [Ne] [Pokaži detalje]"""


TEMPLATES = {
    "deletion": """Ova operacija će obrisati datoteke/kod.

Zahvaćeno: {context}

Želiš nastaviti? [Da] [Ne] [Pregledaj što će se obrisati]""",

    "security": """Ova operacija mijenja sigurnosne postavke.

Akcija: {context}

Jesi li siguran? [Da] [Ne] [Objasni rizike]""",

    "database": """Ova operacija mijenja strukturu baze podataka.

Promjena: {context}

Napomena: Promjene mogu biti nepovratne.
Nastaviti? [Da] [Ne] [Pregledaj migraciju]""",

    "production": """UPOZORENJE: Ova operacija utječe na produkciju.

Akcija: {context}

Preporučujem provjeru prije nego nastavimo.
Nastaviti? [Da] [Ne]"""
}
```

### Block Question (EXTREME)

```python
def format_block_question(critical: List[CriticalAction]) -> str:
    """Format question for extreme critical actions."""

    items = "\n".join(f"• {c.category}: {c.text_context}" for c in critical)

    return f"""EKSTREMNO KRITIČNA OPERACIJA

Ova operacija uključuje potencijalno destruktivne akcije:
{items}

UPOZORENJE: Ove akcije mogu biti NEPOVRATNE.

Za nastavak, upiši "da, siguran sam" ili "yes, I'm sure":"""
```

## Interpretation Generation

```python
def generate_interpretations(intent: ClassifiedIntent) -> List[Interpretation]:
    """Generate possible interpretations of ambiguous intent."""

    interpretations = []

    # Check for homonyms
    homonyms = find_homonyms(intent.raw_input)
    for h in homonyms:
        interpretations.extend(h.meanings)

    # Check for multiple possible scopes
    scopes = infer_possible_scopes(intent)
    for scope in scopes:
        interpretations.append(Interpretation(
            text=f"Misliš {scope.description}?",
            scope=scope,
            confidence=scope.confidence
        ))

    # Check for alternative approaches
    if intent.memory.applicable_patterns:
        for pattern in intent.memory.applicable_patterns[:2]:
            interpretations.append(Interpretation(
                text=f"Koristiti {pattern.name} pristup?",
                approach=pattern,
                confidence=pattern.confidence
            ))

    # Deduplicate and rank
    unique = deduplicate_interpretations(interpretations)
    ranked = sorted(unique, key=lambda x: x.confidence, reverse=True)

    return ranked[:3]  # Max 3 options
```

## Output Structure

```typescript
interface Resolution {
  action: "PROCEED" | "ASK_CHOICE" | "ASK_OPEN" | "BLOCK";
  reason?: string;

  // For ASK_CHOICE
  options?: Interpretation[];

  // For ASK_OPEN or BLOCK
  question?: string;

  // For BLOCK
  requires_explicit?: string;  // What user must type

  // Detected critical actions
  critical_actions?: CriticalAction[];
}

interface CriticalAction {
  category: string;
  severity: "LOW" | "MEDIUM" | "HIGH" | "EXTREME";
  matched: string;
  text_context: string;
}

interface Interpretation {
  text: string;
  scope?: Scope;
  approach?: Pattern;
  confidence: number;
}
```

## Example Resolutions

### PROCEED (Confident, No Critical)

```yaml
input: "Add a logout button to the header"
confidence: 0.95
critical_actions: []

resolution:
  action: "PROCEED"
```

### ASK_CHOICE (Ambiguous)

```yaml
input: "Fix the button"
confidence: 0.45
critical_actions: []

resolution:
  action: "ASK_CHOICE"
  reason: "low_confidence"
  options:
    - text: "Misliš Submit button na login formi?"
      confidence: 0.6
    - text: "Misliš Cancel button u modalu?"
      confidence: 0.3
    - text: "Misliš neki drugi button?"
      confidence: 0.1
```

### ASK (Critical Action)

```yaml
input: "Delete the old auth system"
confidence: 0.9
critical_actions:
  - category: "deletion"
    severity: "HIGH"
    matched: "delete"
    context: "old auth system"

resolution:
  action: "ASK"
  reason: "critical_action"
  question: |
    Ova operacija će obrisati datoteke/kod.

    Zahvaćeno: old auth system

    Želiš nastaviti? [Da] [Ne] [Pregledaj što će se obrisati]
```

### BLOCK (Extreme)

```yaml
input: "rm -rf the entire database folder and rebuild"
confidence: 0.9
critical_actions:
  - category: "deletion"
    severity: "EXTREME"
    matched: "rm -rf"
    context: "entire database folder"

resolution:
  action: "BLOCK"
  reason: "extreme_critical"
  question: |
    EKSTREMNO KRITIČNA OPERACIJA

    Ova operacija uključuje potencijalno destruktivne akcije:
    • deletion: entire database folder

    UPOZORENJE: Ove akcije mogu biti NEPOVRATNE.

    Za nastavak, upiši "da, siguran sam":
  requires_explicit: "da, siguran sam"
```

## Integration

### With Classifier

Receives ClassifiedIntent with:
- Confidence score
- Intent type
- Complexity

### With Strategist

Passes resolution to Strategist:
- If PROCEED → continue to strategy selection
- If ASK* → pause, wait for user response, then continue
- If BLOCK → pause until explicit confirmation

### With User Interaction

Uses AskUserQuestion tool for:
- ASK_CHOICE → present options
- ASK_OPEN → open text input
- BLOCK → require specific text

## Configuration

Users can customize critical action sensitivity:

```yaml
# .claude/config.yaml

resolver:
  sensitivity: "normal"  # low, normal, high, paranoid

  # Override specific categories
  overrides:
    deletion:
      sensitivity: "high"
    dependencies:
      sensitivity: "low"

  # Skip confirmation for specific patterns
  trusted_patterns:
    - "delete node_modules"
    - "clean build artifacts"
```
