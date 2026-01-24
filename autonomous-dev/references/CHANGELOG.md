# Changelog

All notable changes to the autonomous-dev plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
