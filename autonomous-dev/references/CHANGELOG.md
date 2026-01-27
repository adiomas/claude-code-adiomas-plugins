# Changelog

All notable changes to the autonomous-dev plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.2.3] - 2026-01-27

### Fixed
- **Session handoff reliability** - `claude-agi` now properly continues execution
  - Fixed bug where interactive mode would break out of loop instead of continuing
    when status was `in_progress` or `handoff_pending`
  - `stop-hook.sh` now sets `handoff_pending` status before blocking, ensuring
    `claude-agi` can detect and restart if session dies unexpectedly
  - Added `last_heartbeat` timestamp to state for debugging

### Added
- **Auto-update hook** (`setup-auto-update-hook.sh`)
  - Installs git post-push hook that automatically reinstalls `claude-agi`
  - Ensures `claude-agi` binary stays in sync with plugin updates

### Improved
- Better logging in `claude-agi` - shows exit code and status after each session

## [4.2.2] - 2026-01-27

### Improved
- **Documentation clarity for /do vs /auto-prepare workflow**
  - `claude-agi --help` now includes PREREQUISITE section explaining workflow
  - Better error message when `state.yaml` is missing - explains full workflow
  - `/do` command docs now clearly distinguish in-session vs overnight execution
  - Migration table corrected: `/auto-prepare` still needed for overnight mode
  - Added explicit warnings that `/do` does NOT create state files for `claude-agi`

### Fixed
- Updated `claude-agi` version to match plugin version (was 4.0.0, now 4.2.2)

## [4.2.0] - 2026-01-26

### Added
- **Plan Approval Enforcement** (BREAKING CHANGE)
  - `PreToolUse` hook (`enforce-plan-approval.sh`) that BLOCKS Edit/Write operations
  - ORCHESTRATED tasks (complexity >= 3) now REQUIRE explicit user approval
  - `set-plan-approved.sh` helper script for approval state management
  - Hook displays clear error message if approval is missing

- **MCP Server Integrations** (`.mcp.json`)
  - Playwright MCP - Browser automation for E2E testing
  - Sequential Thinking MCP - Structured problem solving
  - Supabase MCP - Database operations and type generation
  - Context7 MCP - Up-to-date library documentation

- **New Skills**
  - `playwright-mcp` - Deep E2E testing with MCP tools (screenshots, forms, accessibility)
  - `supabase-deep` - Database workflow automation (migrations, types, RLS testing)

- **Agent Pool Architecture**
  - `pool-manager.sh` - Dynamic worktree pool management (5-8 parallel agents)
  - Commands: `init`, `acquire`, `release`, `status`, `merge`, `cleanup`, `health`
  - Integrated with `parallel-orchestrator` skill

### Changed
- `/do` command now includes mandatory Plan Approval Gate for ORCHESTRATED strategy
- `strategist.md` updated with approval flow using `AskUserQuestion`
- `orchestrated-executor.md` includes `verify_approval()` check before execution
- `parallel-orchestrator` skill updated to use Agent Pool instead of individual worktrees
- `hooks.json` updated with `PreToolUse` section for enforcement

### Breaking Changes
- ORCHESTRATED tasks will be BLOCKED if user approval is not obtained
- Claude cannot skip the approval step - hook enforcement is automatic

## [4.1.1] - 2026-01-26

### Fixed
- Added YAML frontmatter to `/do`, `/status`, `/cancel` commands for proper parsing

## [4.1.0] - 2026-01-25

### Changed
- Bumped version for stability improvements
- Minor documentation updates

## [4.0.0] - 2026-01-25

### Added
- **AGI-Like Interface** - Single `/do` command replaces all `/auto-*` commands
- **Intent Engine Pipeline** - Parser → Enricher → Classifier → Resolver → Strategist
- **Hybrid Memory System** - Local (project) + Global (cross-project) memory
- **Natural Language Processing** - Reference resolution ("ono od jučer" → yesterday's work)
- **Adaptive Execution** - DIRECT (simple) vs ORCHESTRATED (complex) modes
- **External Orchestrator** - `bin/claude-agi` for multi-session management
- **Learning System** - Pattern extraction, confidence scoring, gotcha discovery

### Changed
- Unified all `/auto-*` commands into single `/do` command
- Complexity-based automatic mode selection
- Token budget system with 80%/95% thresholds

### Deprecated
- `/auto`, `/auto-smart`, `/auto-lite` - Use `/do` instead
- `/auto-status` - Use `/status` instead
- `/auto-cancel` - Use `/cancel` instead

## [3.6.0] - 2026-01-25

### Added
- **AI Code Quality Score** (`ai-code-quality` skill)
  - LLM-based semantic code analysis beyond linting
  - 5 quality dimensions: complexity, maintainability, architecture, duplication, health
  - Configurable thresholds for blocking/warning
  - Detailed reports with recommendations
  - Blocks merge if overall health < 5

- **Auto-Rollback Mechanism** (`rollback-manager` skill)
  - Automatic rollback when verification fails
  - Task rollback (single task), full rollback (checkpoint), partial rollback
  - Rollback history logging for debugging
  - Backup branch creation before destructive actions
  - Configurable retry/skip/abort behavior

- **Accessibility Testing** (WCAG 2.1 AA)
  - axe-core integration in `e2e-validator` skill
  - Checks for perceivable, operable, understandable, robust criteria
  - Violation reports with impact levels and fix suggestions
  - Blocks on critical accessibility violations
  - Configurable standards (wcag2a, wcag2aa, wcag21aa)

### Changed
- `/auto-execute` now includes ai-code-quality analysis in review phase
- `/auto-execute` now auto-rolls back on verification failure
- `e2e-validator` now includes accessibility testing section
- Skills integration table updated with new skills

## [3.5.0] - 2026-01-25

### Added
- **Two-Agent Pattern Workflow** (`/auto-prepare` + `/auto-execute`)
  - `/auto-prepare`: Interactive planning phase with user input
  - `/auto-execute --overnight`: Autonomous execution from prepared state
  - Implements Anthropic's Two-Agent Pattern (Initializer + Coding Agent)
  - Optimized context management with ~1KB bootstrap vs ~50KB full context
- **New Skills**
  - `execution-bootstrap`: Fast context bootstrap from state files
  - `session-handoff`: Proper session ending with state persistence
- **State File Structure** (`.claude/auto-execution/`)
  - `state.yaml`: Machine-readable execution state
  - `tasks.json`: Task list with dependencies (JSON for model safety)
  - `progress.md`: Human-readable progress tracking
  - `next-session.md`: Minimal context for fast session bootstrap
- **Enhanced /auto-execute**
  - `--overnight` flag for fully autonomous execution
  - `--continue` flag for resuming from checkpoints
  - Context limit handling with auto-restart
  - Backwards compatibility with legacy plan-only mode

### Changed
- `/auto-execute` now reads from prepared state files first
- Session handoff protocol for reliable multi-session execution
- Task status tracking with evidence capture

### Documentation
- Added Anthropic best practices research to plan documentation
- Added Cursor scaling agents research findings
- Context engineering guidelines from official documentation

## [3.4.0] - 2025-01-24

### Added
- **Overnight Mode** (`/auto-overnight`): Fully autonomous unattended execution
  - Runs without human intervention for up to 24 hours
  - Uses `--dangerously-skip-permissions` for full autonomy
  - Auto-restarts on context limit with `/auto-continue`
  - Prompt-based completion detection (not string matching)
  - Generates comprehensive overnight report on completion
  - Safety rules to prevent destructive actions
  - Automatic checkpointing and state persistence
- Version sync automation (`scripts/sync-version.sh`)
- Version bump helper (`scripts/bump-version.sh`)
- Git pre-commit hook for automatic version sync

### Changed
- Updated plugin.json keywords with "overnight-mode" and "unattended"

## [3.3.0] - 2025-01-20

### Added
- **Smart Ralph Mode** (`/auto-smart`): Intelligent autonomous development
  - Automatic complexity detection (scale 1-5)
  - DIRECT mode for simple tasks (complexity 1-2)
  - ORCHESTRATED mode for complex tasks (complexity 3-5)
  - Evidence gates prevent hallucinations
  - Graduated failure recovery (Pivot → Research → Checkpoint)
  - Auto-resume on session restart
  - NO approval gates - fully autonomous "fire and forget"
- `skills/smart-mode/` for complexity analysis
- State persistence in `.claude/smart-ralph/`

### Changed
- Improved failure handling with 3-level recovery protocol

## [3.2.0] - 2025-01-18

### Added
- Anthropic engineering best practices integration
- Enhanced TDD enforcement across all modes
- Improved verification pipeline with early failure detection

### Changed
- Refined task decomposition heuristics
- Better error messages and debugging output

### Fixed
- Hardcoded version in auto-version command

## [3.1.1] - 2025-01-17

### Fixed
- Shell scripts arithmetic operations failing with `set -e`
- Replaced all `bc` usage with `awk` for cross-platform compatibility

### Added
- `check-dependencies.sh` for dependency validation
- `recover-state.sh` for state recovery
- Test suite in `tests/` directory
- `references/ARCHITECTURE.md` explaining plugin architecture
- "When NOT to use" sections in all skills
- "Quality Standards" sections in all skills

### Changed
- All scripts now use `set -euo pipefail`
- All commands now have `name` and `argument-hint` fields

## [3.1.0] - 2025-01-17

### Added
- Automatic parallelization decision based on task count threshold
- State machine architecture for workflow management
- Token budget monitoring with graceful degradation
- Checkpoint system for session resume capability
- Database provider detection (Supabase, Firebase, Prisma, etc.)
- MCP availability detection for schema validation

### Changed
- Updated plugin.json with license, homepage, repository fields
- Improved skill trigger phrases for better auto-detection

### Fixed
- Validation script arithmetic operations causing early exit with `set -e`
- Missing trigger phrases in work-type-classifier skill

## [3.0.0] - 2025-01-16

### Added
- State machine architecture for phase management
- Semantic work type classification (FRONTEND, BACKEND, FULLSTACK, RESEARCH, etc.)
- Token budget controller with phase-specific budgets
- Graceful degradation when limits approached
- Session checkpoint and resume capability (`/auto-continue`)
- Integration with superpowers skills for development discipline

### Changed
- Complete architectural rewrite for reliability
- Switched from linear execution to state machine model
- Improved parallel orchestration with better error handling

## [2.0.0] - 2025-01-15

### Added
- Parallel execution using git worktrees
- Conflict resolution skill
- Mutation testing integration
- Project profile caching

### Changed
- Moved from simple sequential to parallel execution model
- Enhanced project detection with more frameworks

## [1.0.0] - 2025-01-10

### Added
- Initial release
- Basic autonomous development workflow
- Project detection for major frameworks
- Task decomposition
- Verification pipeline
- Commands: `/auto`, `/auto-plan`, `/auto-execute`, `/auto-status`, `/auto-cancel`
