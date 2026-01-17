---
name: auto-audit
description: Dedicated research/audit workflow for security audits, code analysis, and exploration tasks
---

# /auto-audit - Research & Audit Workflow

Specialized workflow for research, security audits, and analysis tasks that don't require code implementation.

## When to Use

Use `/auto-audit` instead of `/auto` when:
- Security audit requested ("audit auth", "check for vulnerabilities")
- Code analysis needed ("analyze this codebase", "review architecture")
- Research tasks ("explore how X works", "find all usages of Y")
- Documentation review ("check docs accuracy", "find outdated docs")
- Performance analysis ("find bottlenecks", "analyze slow queries")

## Key Differences from /auto

| Aspect | /auto | /auto-audit |
|--------|-------|-------------|
| **TDD** | Required | Not applicable |
| **Worktrees** | Parallel execution | Single-threaded |
| **Output** | Code + tests | Report document |
| **Skills** | Implementation skills | Analysis skills |
| **Phases** | 7 phases | 4 phases (R1-R4) |

## Research Workflow (R1-R4)

### Phase R1: SCOPE DEFINITION

Define what we're auditing and how:

```yaml
# Output: .claude/audit-scope.yaml
audit:
  target: "authentication system"
  type: SECURITY | ARCHITECTURE | PERFORMANCE | DOCUMENTATION
  checklist: OWASP | CUSTOM | AUTO
  output_format: REPORT | FINDINGS | RECOMMENDATIONS

scope:
  include:
    - "src/auth/**"
    - "src/middleware/auth*"
    - "lib/session*"
  exclude:
    - "**/*.test.ts"
    - "**/mocks/**"

focus_areas:
  - "SQL injection"
  - "XSS vulnerabilities"
  - "Authentication bypass"
  - "Session management"
  - "Input validation"
```

**Questions to ask user:**
1. What specific aspects should we audit?
2. Any known concerns or areas of focus?
3. What format do you want the findings in?

### Phase R2: SYSTEMATIC EXPLORATION

Map the target codebase systematically:

```bash
# Find all relevant files
Glob: "src/auth/**/*.ts"
Glob: "**/middleware/*.ts"
Grep: "password|token|session|auth"

# Trace data flows
- Input points (API endpoints, forms)
- Processing (validation, transformation)
- Output (responses, storage)

# Identify trust boundaries
- External inputs (user data, API calls)
- Internal boundaries (service calls)
- Storage boundaries (database, cache)
```

**Create exploration map:**
```yaml
# .claude/audit-exploration.yaml
files_analyzed:
  - path: "src/auth/login.ts"
    purpose: "User authentication endpoint"
    trust_boundary: "external_input"

data_flows:
  - name: "Login flow"
    entry: "POST /api/auth/login"
    steps:
      - "Receive credentials"
      - "Validate format"
      - "Query database"
      - "Generate JWT"
      - "Set cookie"

trust_boundaries:
  - name: "User input"
    location: "API endpoints"
    validation: "partial"
```

### Phase R3: ANALYSIS

Apply systematic analysis based on audit type:

#### For SECURITY audits:

Check against OWASP Top 10:
1. **Injection** - SQL, NoSQL, OS command injection
2. **Broken Authentication** - Session management, credential storage
3. **Sensitive Data Exposure** - Encryption, data leakage
4. **XXE** - XML external entity attacks
5. **Broken Access Control** - Authorization checks
6. **Security Misconfiguration** - Default configs, error handling
7. **XSS** - Reflected, stored, DOM-based
8. **Insecure Deserialization** - Object manipulation
9. **Known Vulnerabilities** - Outdated dependencies
10. **Insufficient Logging** - Audit trails

For each finding:
```yaml
finding:
  id: "SEC-001"
  severity: CRITICAL | HIGH | MEDIUM | LOW | INFO
  category: "Injection"
  title: "SQL Injection in user lookup"
  location: "src/auth/user.ts:45"
  description: "User input directly concatenated into SQL query"
  evidence: |
    const query = `SELECT * FROM users WHERE id = ${userId}`;
  risk: "Attacker can extract or modify database contents"
  remediation: "Use parameterized queries"
  code_fix: |
    const query = 'SELECT * FROM users WHERE id = $1';
    db.query(query, [userId]);
```

#### For ARCHITECTURE audits:

Check against principles:
- Separation of concerns
- Single responsibility
- Dependency inversion
- Interface segregation

#### For PERFORMANCE audits:

Check for:
- N+1 queries
- Missing indexes
- Unnecessary re-renders
- Large bundle sizes
- Memory leaks

### Phase R4: REPORT GENERATION

Create structured audit report:

```markdown
# Security Audit Report: Authentication System
Generated: 2024-01-15
Auditor: Claude (autonomous-dev)

## Executive Summary
- **Overall Risk Level:** HIGH
- **Critical Findings:** 2
- **High Findings:** 3
- **Medium Findings:** 5
- **Low Findings:** 8

## Scope
- Files analyzed: 23
- Lines of code: 2,450
- Time period: Current main branch

## Critical Findings

### SEC-001: SQL Injection in User Lookup
**Severity:** CRITICAL
**Location:** src/auth/user.ts:45
**Description:** ...
**Remediation:** ...

### SEC-002: Hardcoded JWT Secret
**Severity:** CRITICAL
**Location:** src/auth/jwt.ts:12
**Description:** ...
**Remediation:** ...

## High Findings
...

## Recommendations
1. Immediately fix critical findings
2. Implement parameterized queries throughout
3. Move secrets to environment variables
4. Add input validation layer

## Appendix
- Full file list analyzed
- Methodology details
- Tool versions used
```

**Output location:** `docs/audits/YYYY-MM-DD-<target>-audit.md`

## State Machine Integration

```yaml
# .claude/auto-state-machine.yaml for audit
version: "3.0"
current_state: "RESEARCH"
work_type: "RESEARCH"
research_phase: "R2"  # R1, R2, R3, R4
audit_type: "SECURITY"
```

## Skills Invoked

For SECURITY audits:
- `code-reviewer` (security mode)
- Pattern matching for vulnerability patterns

For ARCHITECTURE audits:
- `architecture-patterns`
- `senior-architect` (if available)

For PERFORMANCE audits:
- Performance profiling patterns
- Query analysis

## Example Usage

```
User: /auto-audit Audit the authentication system for security vulnerabilities

Claude: Starting security audit workflow...

=== PHASE R1: SCOPE DEFINITION ===
Target: Authentication system
Type: SECURITY
Checklist: OWASP Top 10

Identified scope:
- src/auth/** (12 files)
- src/middleware/auth* (3 files)
- lib/session* (2 files)

Any specific concerns you want me to focus on?

User: Focus on SQL injection and session management

Claude: Added focus areas. Proceeding to exploration...

=== PHASE R2: EXPLORATION ===
Mapping authentication data flows...
[exploration continues...]

=== PHASE R3: ANALYSIS ===
Applying OWASP checklist with focus on:
- SQL Injection
- Session Management
[analysis continues...]

=== PHASE R4: REPORT ===
Generating audit report...

Report saved to: docs/audits/2024-01-15-auth-security-audit.md

Summary:
- 2 CRITICAL findings
- 3 HIGH findings
- 5 MEDIUM findings

<promise>AUDIT_COMPLETE</promise>
```

## Completion Promise

For audit tasks, use: `<promise>AUDIT_COMPLETE</promise>`

This signals the audit workflow is complete and the report has been generated.
