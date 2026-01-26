---
name: auto-version
description: Show autonomous-dev plugin version
argument-hint: ""
allowed-tools: []
---

# Autonomous Dev Plugin Version

**Version: 4.1.1**

Plugin: autonomous-dev
Marketplace: adiomas-plugins

## What's New in 4.1.1

- **AI Code Quality Score** - Semantic code quality analysis
  - Complexity score (1-10): Cognitive load measurement
  - Maintainability index (1-10): Long-term code health
  - Architecture compliance (1-10): Pattern adherence
  - Duplication score (1-10): DRY compliance
  - Overall health score (1-10): Weighted average
  - Blocks merge if quality below thresholds

- **Auto-Rollback** - Automatic recovery from failures
  - Task rollback: Revert single task changes
  - Full rollback: Return to last checkpoint
  - Partial rollback: Keep working, revert broken
  - Rollback history logging
  - Backup branch creation before destructive actions

- **Accessibility Testing (WCAG 2.1 AA)**
  - axe-core integration for a11y audit
  - Perceivable, Operable, Understandable, Robust checks
  - Blocks on critical accessibility violations
  - Detailed violation reports with fix suggestions

- **New Skills**
  - `ai-code-quality`: LLM-based code analysis
  - `rollback-manager`: Auto-rollback on verify fail
