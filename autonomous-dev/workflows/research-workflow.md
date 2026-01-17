# Research Workflow (R1-R4)

Dedicated workflow for research, audit, and analysis tasks that don't involve code implementation.

## Overview

The Research Workflow replaces the standard 7-phase implementation workflow when the task is:
- Security audit
- Code analysis
- Architecture review
- Performance investigation
- Documentation review
- Codebase exploration

## Phase Definitions

### Phase R1: SCOPE DEFINITION

**Goal:** Define exactly what we're researching and how.

**Inputs:**
- User's original request
- Any specific focus areas mentioned

**Process:**
1. Parse the request to identify:
   - Target system/component
   - Type of research (security, performance, architecture, etc.)
   - Desired output format
2. Ask clarifying questions (ONE at a time):
   - "What specific aspects should I focus on?"
   - "Are there known concerns I should prioritize?"
   - "What format do you want the findings in?"
3. Define scope boundaries:
   - Files/directories to include
   - Files/directories to exclude
   - Trust boundaries

**Outputs:**
```yaml
# .claude/audit-scope.yaml
audit:
  target: "<system being audited>"
  type: SECURITY | ARCHITECTURE | PERFORMANCE | DOCUMENTATION
  checklist: OWASP | CUSTOM | AUTO
  output_format: REPORT | FINDINGS | RECOMMENDATIONS

scope:
  include:
    - "pattern1"
    - "pattern2"
  exclude:
    - "pattern1"

focus_areas:
  - "area1"
  - "area2"
```

**Checkpoint:** `.claude/auto-memory/phase-r1-scope.md`

---

### Phase R2: SYSTEMATIC EXPLORATION

**Goal:** Map the target codebase comprehensively.

**Inputs:**
- Scope definition from R1
- Project profile (if exists)

**Process:**
1. File discovery:
   ```bash
   Glob: "<scope.include patterns>"
   ```
2. Content analysis:
   ```bash
   Grep: "<relevant patterns for audit type>"
   ```
3. Data flow tracing:
   - Identify entry points (APIs, forms, event handlers)
   - Trace processing logic
   - Map output/storage points
4. Trust boundary identification:
   - External inputs
   - Service boundaries
   - Storage interfaces

**Outputs:**
```yaml
# .claude/audit-exploration.yaml
files_analyzed:
  - path: "path/to/file.ts"
    purpose: "Description"
    trust_boundary: "external_input | internal | storage"
    key_functions:
      - name: "functionName"
        line: 45
        risk_indicators: ["user_input", "database_query"]

data_flows:
  - name: "Flow Name"
    entry: "Entry point"
    steps:
      - "Step 1"
      - "Step 2"
    exit: "Exit point"

trust_boundaries:
  - name: "Boundary name"
    location: "Where"
    validation_status: "none | partial | complete"
```

**Checkpoint:** `.claude/auto-memory/phase-r2-exploration.md`

---

### Phase R3: ANALYSIS

**Goal:** Apply systematic analysis based on audit type.

**Inputs:**
- Exploration map from R2
- Checklist for audit type

**Process:**

#### For SECURITY Audits (OWASP Top 10):

| Category | What to Check |
|----------|---------------|
| A01 Broken Access Control | Missing auth checks, IDOR, privilege escalation |
| A02 Cryptographic Failures | Weak encryption, exposed secrets, insecure transmission |
| A03 Injection | SQL, NoSQL, OS command, LDAP injection |
| A04 Insecure Design | Missing threat modeling, insecure patterns |
| A05 Security Misconfiguration | Default configs, unnecessary features, verbose errors |
| A06 Vulnerable Components | Outdated dependencies, known CVEs |
| A07 Auth Failures | Weak passwords, missing MFA, session issues |
| A08 Data Integrity Failures | Insecure deserialization, unsigned updates |
| A09 Logging Failures | Missing audit logs, log injection |
| A10 SSRF | Unvalidated URLs, internal network access |

#### For ARCHITECTURE Audits:

| Principle | What to Check |
|-----------|---------------|
| Separation of Concerns | Mixed responsibilities, god objects |
| Single Responsibility | Classes/functions doing too much |
| Dependency Inversion | Concrete dependencies, tight coupling |
| Interface Segregation | Fat interfaces, unused methods |
| Open/Closed | Modification vs extension patterns |
| DRY | Code duplication, copy-paste patterns |

#### For PERFORMANCE Audits:

| Issue | What to Check |
|-------|---------------|
| N+1 Queries | Loop with database calls |
| Missing Indexes | Slow queries, full table scans |
| Memory Leaks | Event listeners, closures, caches |
| Bundle Size | Unused imports, large dependencies |
| Re-renders | Unnecessary component updates |
| Caching | Missing cache, cache invalidation |

**For each finding:**
```yaml
finding:
  id: "<TYPE>-<NUMBER>"
  severity: CRITICAL | HIGH | MEDIUM | LOW | INFO
  category: "<Category from checklist>"
  title: "<Brief title>"
  location: "<file:line>"
  description: "<What's wrong>"
  evidence: |
    <Code snippet or proof>
  risk: "<What could go wrong>"
  remediation: "<How to fix>"
  code_fix: |
    <Suggested fix if applicable>
  references:
    - "<Link to relevant documentation>"
```

**Checkpoint:** `.claude/auto-memory/phase-r3-findings.yaml`

---

### Phase R4: REPORT GENERATION

**Goal:** Create actionable, well-structured report.

**Inputs:**
- All findings from R3
- Scope and exploration data

**Process:**
1. Sort findings by severity (CRITICAL first)
2. Group related findings
3. Generate executive summary
4. Create detailed finding descriptions
5. Write recommendations section
6. Add appendix with methodology

**Output Template:**
```markdown
# [Audit Type] Audit Report: [Target]

Generated: [Date]
Auditor: Claude (autonomous-dev v3.0)

## Executive Summary

**Overall Risk Level:** [CRITICAL/HIGH/MEDIUM/LOW]

| Severity | Count |
|----------|-------|
| Critical | X |
| High | X |
| Medium | X |
| Low | X |
| Info | X |

**Key Findings:**
- [Most important finding 1]
- [Most important finding 2]
- [Most important finding 3]

## Scope

**Target:** [What was audited]
**Files Analyzed:** [Count]
**Lines of Code:** [Count]
**Analysis Period:** [Date range or commit]

### Included
- [Pattern 1]
- [Pattern 2]

### Excluded
- [Pattern 1]

## Findings

### Critical

#### [ID]: [Title]
**Severity:** CRITICAL
**Location:** [file:line]
**Category:** [OWASP/Architecture/Performance category]

**Description:**
[Detailed description]

**Evidence:**
```
[Code or proof]
```

**Risk:**
[What could go wrong]

**Remediation:**
[How to fix]

**Suggested Fix:**
```
[Code fix]
```

---

### High
[Similar format...]

### Medium
[Similar format...]

### Low
[Similar format...]

## Recommendations

### Immediate Actions (Critical/High)
1. [Action 1]
2. [Action 2]

### Short-term (Medium)
1. [Action 1]
2. [Action 2]

### Long-term (Low/Improvements)
1. [Action 1]
2. [Action 2]

## Appendix

### Methodology
- [How the audit was conducted]
- [Tools/patterns used]

### Files Analyzed
- [Full list of files]

### References
- [Relevant documentation links]
```

**Output Location:** `docs/audits/YYYY-MM-DD-<target>-<type>-audit.md`

**Completion Signal:** `<promise>AUDIT_COMPLETE</promise>`

---

## State Machine Integration

When in RESEARCH workflow:

```yaml
# .claude/auto-state-machine.yaml
current_state: "RESEARCH"
work_type: "RESEARCH"
research_phase: "R1" | "R2" | "R3" | "R4"
audit_type: "SECURITY" | "ARCHITECTURE" | "PERFORMANCE" | "DOCUMENTATION"
```

Transitions:
- R1 complete → `research_phase: "R2"`
- R2 complete → `research_phase: "R3"`
- R3 complete → `research_phase: "R4"`
- R4 complete → `current_state: "COMPLETE"`

## What NOT to Do

- ❌ Do NOT write implementation code
- ❌ Do NOT create tests (except for demonstrating vulnerabilities)
- ❌ Do NOT use git worktrees
- ❌ Do NOT apply TDD workflow
- ❌ Do NOT skip directly to findings without exploration

## Skills Used

| Phase | Skills |
|-------|--------|
| R1 | (none - user interaction) |
| R2 | Glob, Grep, Read (systematic) |
| R3 | code-reviewer (analysis mode) |
| R4 | (report generation) |
