# Changelog

All notable changes to the autonomous-dev plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.0] - 2025-01-17

### Added
- Automatic parallelization decision based on task count threshold
- State machine architecture for workflow management
- Token budget monitoring with graceful degradation
- Checkpoint system for session resume capability
- Dependency checking script (`check-dependencies.sh`)
- "When NOT to use" sections in all skills
- Quality Standards sections in all skills
- Database provider detection (Supabase, Firebase, Prisma, etc.)
- MCP availability detection for schema validation

### Changed
- Replaced all `bc` usage with `awk` for cross-platform compatibility
- All scripts now use `set -euo pipefail` for robustness
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
