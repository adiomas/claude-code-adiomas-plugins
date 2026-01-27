---
name: auto-version
description: Show autonomous-dev plugin version
argument-hint: ""
allowed-tools: []
---

# Autonomous Dev Plugin Version

**Version: 4.2.2**

Plugin: autonomous-dev
Marketplace: adiomas-plugins

## What's New in 4.2.2

- **Session Handoff Fix** - Reliable multi-session execution
  - Fixed: `claude-agi` now properly continues when status is `in_progress`/`handoff_pending`
  - `stop-hook.sh` sets `handoff_pending` for better session death detection
  - Improved logging shows exit code and status after each session

- **Auto-Update Hook** - Keep `claude-agi` in sync
  - New: `setup-auto-update-hook.sh` installs git post-push hook
  - Automatically reinstalls `claude-agi` after pushing plugin changes

## What's New in 4.2.2

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
