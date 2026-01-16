# Superpowers Integration Guide

This guide explains how autonomous-dev integrates with superpowers skills to enforce development discipline and maximize implementation quality.

## Overview

The autonomous-dev plugin uses superpowers skills as **discipline enforcement** throughout the 6-phase workflow. These skills are not optional enhancements—they are mandatory quality gates.

## Skill Integration by Phase

### Phase 1: Project Detection + Work Type Classification

**No superpowers skills invoked.**

Internal skills only:
- `project-detector` - Detect tech stack
- `work-type-classifier` - Classify work type and create skill activation plan

### Phase 2: Requirement Understanding

**MANDATORY:** `superpowers:brainstorming`

```
Invoke: superpowers:brainstorming
```

**What it enforces:**
- Ask ONE clarifying question at a time (never multiple)
- Apply YAGNI ruthlessly - remove unnecessary features
- Explore alternatives before settling on approach
- Create design document before proceeding

**Output:** `docs/plans/YYYY-MM-DD-<topic>-design.md`

**Completion criteria:**
- User confirmed "Yes, that's what I want"
- Clear scope definition
- Success criteria defined
- Constraints identified

### Phase 3: Planning

**MANDATORY:** `superpowers:writing-plans`

```
Invoke: superpowers:writing-plans
```

**What it enforces:**
- Bite-sized tasks (2-5 minutes each)
- Exact code snippets for each task
- TDD test cases built-in
- File paths and expected outputs

**Output:** `.claude/plans/auto-{timestamp}.md`

### Phase 4: Execution

**MANDATORY:** `superpowers:test-driven-development`

```
Invoke: superpowers:test-driven-development
```

**What it enforces:**
- **RED:** Write ONE minimal failing test FIRST
- **GREEN:** Write ONLY enough code to pass
- **REFACTOR:** Clean up while tests pass

**Iron Law:** "NO PRODUCTION CODE WITHOUT FAILING TEST FIRST"

**Conditional:** `superpowers:systematic-debugging`

```
Invoke when: Tests fail unexpectedly
```

**What it enforces:**
- 4-phase protocol: Investigation → Analysis → Hypothesis → Implementation
- NO random fixes allowed
- Max 3 fix attempts before escalating

**Red Flag:** "Let me just try changing X" → STOP, return to Investigation Phase

### Phase 5: Integration

**OPTIONAL:** `superpowers:finishing-a-development-branch`

```
Invoke: superpowers:finishing-a-development-branch
```

**What it provides:**
- Clear options: Merge locally, Create PR, Keep, Discard
- Verification before any action
- Cleanup automation

### Phase 6: Review

**MANDATORY:** `superpowers:verification-before-completion`

```
Invoke: superpowers:verification-before-completion
```

**What it enforces:**
- Gate Function: IDENTIFY → RUN → READ → VERIFY → CLAIM
- Run ALL verification commands fresh
- Show ACTUAL output, not assumptions

**Red Flags - Never say:**
- "Tests should pass" → Run them and show output
- "Build probably works" → Run build and show exit code
- "I think lint is clean" → Run linter and show 0 errors

**MANDATORY:** `superpowers:requesting-code-review`

```
Invoke: superpowers:requesting-code-review
```

**What it provides:**
- Structured review request format
- Dispatch code-reviewer subagent

**Conditional:** `superpowers:receiving-code-review`

```
Invoke when: Receiving feedback on implementation
```

**What it enforces:**
- Technical rigor over performative agreement
- Verify suggestions before implementing
- Never say "You're absolutely right!" without verification

## Discipline Principles (NON-NEGOTIABLE)

### 1. TDD Discipline
- No production code without failing test first
- Tests-first asks "what SHOULD this do?" (not "what DOES this do?")
- Skip only if genuinely impossible (rare)

### 2. Systematic Debugging
- Never randomly try fixes
- Form hypothesis before changing code
- Max 3 attempts, then escalate with evidence

### 3. Evidence-Based Verification
- No claims without fresh command output
- Exit code + actual output = evidence
- Words like "should", "probably" = red flags

### 4. YAGNI (You Aren't Gonna Need It)
- Don't add features "just in case"
- Stick to requirements
- Ask before expanding scope

### 5. One Question at a Time
- Never ask multiple questions in one message
- Let user answer before next question
- Reduces cognitive load

## How to Invoke Skills

In autonomous-dev workflow, use the Skill tool:

```
Use the Skill tool with skill: "superpowers:brainstorming"
```

The skill content will load and must be followed exactly.

## Failure Escalation

When discipline cannot be maintained:

| Situation | Action |
|-----------|--------|
| 3 TDD cycles fail | Escalate with evidence to user |
| 3 debugging attempts fail | Stop and report root cause analysis |
| Verification fails repeatedly | Document what's failing and why |
| User rejects brainstorming output | Ask for clarification, don't guess |

## Integration with Domain Skills

Discipline skills work **alongside** domain-specific skills:

```
Phase 2:
  1. Invoke superpowers:brainstorming (ALWAYS)
  2. Read .claude/auto-context.yaml
  3. IF work_type == "FRONTEND": Also invoke frontend-design

Phase 4:
  1. Invoke superpowers:test-driven-development (ALWAYS)
  2. Apply domain skills during implementation
  3. IF tests fail: invoke superpowers:systematic-debugging

Phase 6:
  1. Invoke superpowers:verification-before-completion (ALWAYS)
  2. IF work_type == "FRONTEND": Run webapp-testing with Playwright
  3. Invoke superpowers:requesting-code-review (ALWAYS)
```

## Expected Quality Improvement

### Before Integration:
- Autonomni development works but without discipline
- Possible to skip tests
- Possible random fixes when something fails
- Completion claims without evidence

### After Integration:
- Every feature goes through brainstorming before planning
- Every task follows TDD cycle (RED → GREEN → REFACTOR)
- Every bug is debugged systematically
- Every completion claim has fresh evidence
- Every code review processed with technical rigor

**Estimated quality improvement: 40-60%** through disciplined application of superpowers workflows.

## Quick Reference

| Phase | Always Invoke | Conditional |
|-------|---------------|-------------|
| 1 | - | - |
| 2 | brainstorming | frontend-design (if FRONTEND) |
| 3 | writing-plans | - |
| 4 | test-driven-development | systematic-debugging (if failure) |
| 5 | - | finishing-a-development-branch |
| 6 | verification-before-completion, requesting-code-review | receiving-code-review (if feedback), webapp-testing (if FRONTEND) |
