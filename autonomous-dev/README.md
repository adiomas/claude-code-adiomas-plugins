# Autonomous Dev Plugin

Universal autonomous development system for Claude Code. Describe what you want, and let Claude handle the rest - from planning to implementation to verification.

## Features

- **Intelligent Project Detection** - Auto-detects tech stack (Next.js, Vite, Django, FastAPI, Go, Rust, etc.)
- **Work Type Classification** - Detects FRONTEND/BACKEND/FULLSTACK/etc. and invokes domain-specific skills
- **Requirement Gathering** - Asks focused clarifying questions before implementing (via `superpowers:brainstorming`)
- **Smart Task Decomposition** - Creates atomic, parallelizable tasks with dependencies
- **TDD Discipline** - Enforces RED→GREEN→REFACTOR cycle (via `superpowers:test-driven-development`)
- **Systematic Debugging** - Root cause analysis, no random fixes (via `superpowers:systematic-debugging`)
- **Parallel Execution** - Runs independent tasks simultaneously using isolated git worktrees
- **Evidence-Based Verification** - Fresh verification output, no assumptions (via `superpowers:verification-before-completion`)
- **Comprehensive Verification** - Runs typecheck → lint → test → build in optimal order
- **AI Conflict Resolution** - Intelligently resolves merge conflicts or escalates when uncertain
- **Real-time Progress** - Track execution status with `/auto-status`
- **User Approval Gates** - Always gets your approval before execution and after completion
- **Domain-Specific Quality** - Invokes `frontend-design`, `architecture-patterns`, etc. based on work type

## Prerequisites

Install required tools:

```bash
# macOS
brew install yq jq

# Ubuntu/Debian
sudo apt install yq jq

# Arch Linux
sudo pacman -S yq jq

# Or via npm (yq only)
npm install -g yq
```

## Quick Start

```bash
# Start Claude Code
claude

# Full autonomous mode
/auto Add user authentication with JWT tokens

# Or plan first, execute later
/auto-plan Add a dashboard with analytics
# Review plan at .claude/plans/auto-*.md
/auto-execute

# Check progress during execution
/auto-status

# Cancel if needed
/auto-cancel
```

## Commands

| Command | Description | Usage |
|---------|-------------|-------|
| `/auto` | Full autonomous development mode | `/auto <feature description>` |
| `/auto-plan` | Create plan without executing | `/auto-plan <feature description>` |
| `/auto-execute` | Execute existing approved plan | `/auto-execute [plan-file]` |
| `/auto-status` | Check execution progress | `/auto-status` |
| `/auto-cancel` | Cancel and clean up | `/auto-cancel` |

## How It Works

```
YOU: "Add feature X"
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│  PHASE 1: PROJECT DETECTION                                │
│  • Detect tech stack (language, framework, package manager)│
│  • Extract test/lint/build commands                        │
│  • Create .claude/project-profile.yaml                     │
└────────────────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│  PHASE 2: REQUIREMENT UNDERSTANDING                        │
│  • Ask ONE clarifying question at a time                   │
│  • Confirm scope and success criteria                      │
│  • Identify constraints and preferences                    │
└────────────────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│  PHASE 3: PLANNING                                         │
│  • Decompose into atomic, verifiable tasks                 │
│  • Map dependencies and parallel groups                    │
│  • Create execution plan at .claude/plans/auto-*.md        │
│  ★ GET YOUR APPROVAL BEFORE PROCEEDING ★                   │
└────────────────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│  PHASE 4: PARALLEL EXECUTION                               │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐          │
│  │  Worktree 1 │ │  Worktree 2 │ │  Worktree 3 │          │
│  │  auto/task1 │ │  auto/task2 │ │  auto/task3 │          │
│  │  Agent A    │ │  Agent B    │ │  Agent C    │          │
│  └─────────────┘ └─────────────┘ └─────────────┘          │
│  Each agent: implement → verify → commit → signal done     │
└────────────────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│  PHASE 5: INTEGRATION                                      │
│  • Merge branches in dependency order                      │
│  • Auto-resolve simple conflicts                           │
│  • Escalate complex conflicts to user                      │
│  • Clean up worktrees                                      │
└────────────────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│  PHASE 6: REVIEW                                           │
│  • Run full verification pipeline                          │
│  • Present summary of changes                              │
│  • Offer to create PR, make adjustments, or show details   │
│  ★ GET YOUR APPROVAL BEFORE COMPLETION ★                   │
└────────────────────────────────────────────────────────────┘
```

## Skills

The plugin includes specialized skills that Claude loads automatically:

### Internal Skills

| Skill | Triggers When | Purpose |
|-------|---------------|---------|
| **project-detector** | "detect project", "analyze this project" | Detects tech stack and creates profile |
| **task-decomposer** | "break down this feature", "create task list" | Decomposes features into atomic tasks |
| **parallel-orchestrator** | "run tasks in parallel", "create worktrees" | Manages parallel agent execution |
| **verification-runner** | "run verification", "check if code passes" | Runs test/lint/typecheck/build pipeline |
| **conflict-resolver** | "resolve merge conflicts", "fix git conflicts" | AI-powered conflict resolution |
| **work-type-classifier** | Start of /auto command | Detects work type and maps to domain skills |

### Superpowers Integration (Discipline Skills)

The plugin integrates with **superpowers** skills for development discipline:

| Skill | Phase | Purpose |
|-------|-------|---------|
| `superpowers:brainstorming` | 2 | Turn vague ideas into clear specs |
| `superpowers:writing-plans` | 3 | Create detailed implementation plans |
| `superpowers:test-driven-development` | 4 | TDD discipline (RED→GREEN→REFACTOR) |
| `superpowers:systematic-debugging` | 4 | Root cause analysis when tests fail |
| `superpowers:verification-before-completion` | 6 | Evidence before claims |
| `superpowers:requesting-code-review` | 6 | Structured review workflow |
| `superpowers:receiving-code-review` | 6 | Process feedback with rigor |

### Domain-Specific Skills (Auto-Detected)

Based on work type, these skills are automatically invoked:

| Work Type | Skills Invoked |
|-----------|----------------|
| **FRONTEND** | `frontend-design`, `webapp-testing` |
| **BACKEND** | `architecture-patterns`, `api-design-principles` |
| **FULLSTACK** | `frontend-design`, `architecture-patterns` |
| **DOCUMENTATION** | `doc-coauthoring` |
| **DOCUMENTS** | `pdf`, `docx`, `xlsx`, `pptx` |
| **INTEGRATION** | `mcp-builder` |
| **CREATIVE** | `canvas-design`, `algorithmic-art` |

See `references/superpowers-integration.md` for detailed integration guide.
See `skills/work-type-classifier/references/skill-catalog.md` for complete skill catalog.

## Agents

Specialized agents for autonomous tasks:

| Agent | Purpose |
|-------|---------|
| **task-executor** | Executes single atomic tasks in isolated worktrees |
| **code-reviewer** | Reviews code changes for quality and security |
| **verification-agent** | Runs comprehensive verification with diagnostics |

## Configuration

Auto-detection works for most projects, but you can customize by editing `.claude/project-profile.yaml`:

```yaml
project:
  name: my-app
  type: fullstack  # frontend, backend, fullstack

stack:
  language: typescript/javascript
  framework: next.js
  package_manager: pnpm

commands:
  test: pnpm test
  lint: pnpm lint
  typecheck: pnpm typecheck
  build: pnpm build
  dev: pnpm dev

verification:
  required:      # Must pass for completion
    - typecheck
    - lint
    - test
  optional:      # Run but don't block
    - build

patterns:
  source: src/
  tests: "**/*.test.ts"
  components: src/components/
  api: src/app/api/
```

## Project Support

### Fully Supported

| Language | Frameworks | Package Managers |
|----------|------------|------------------|
| **TypeScript/JavaScript** | Next.js, Vite, Nuxt, Astro, SvelteKit | npm, yarn, pnpm, bun |
| **Python** | Django, FastAPI, Flask | pip, poetry |
| **Go** | Standard library, Gin, Echo | go mod |
| **Rust** | Actix-web, Axum, Rocket | cargo |

### Partially Supported

- Java (Maven, Gradle) - basic detection
- PHP (Laravel, Symfony) - basic detection
- Ruby (Rails) - basic detection

## Hooks

The plugin uses hooks for lifecycle management:

| Event | Hook | Purpose |
|-------|------|---------|
| SessionStart | `detect-project.sh` | Auto-detect project on session start |
| Stop | `stop-hook.sh` | Track iteration count, detect completion |
| PostToolUse (Edit/Write) | `post-tool.sh` | Optional auto-verification after edits |

## File Structure

```
~/.claude/plugins/autonomous-dev/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest
├── commands/                  # Slash commands
│   ├── auto.md               # Main autonomous command
│   ├── auto-plan.md          # Planning only
│   ├── auto-execute.md       # Execute existing plan
│   ├── auto-status.md        # Check progress
│   └── auto-cancel.md        # Cancel and cleanup
├── skills/                    # Auto-loading skills
│   ├── project-detector/
│   │   ├── SKILL.md
│   │   ├── references/       # Detailed framework docs
│   │   └── examples/         # Sample profiles
│   ├── task-decomposer/
│   │   ├── SKILL.md
│   │   ├── references/       # Decomposition patterns
│   │   └── examples/         # Example decompositions
│   ├── parallel-orchestrator/
│   │   ├── SKILL.md
│   │   └── references/       # Worktree management guide
│   ├── verification-runner/
│   │   ├── SKILL.md
│   │   └── references/       # Verification commands
│   ├── conflict-resolver/
│   │   ├── SKILL.md
│   │   └── references/       # Conflict patterns
│   └── work-type-classifier/
│       ├── SKILL.md          # Work type detection
│       └── references/
│           └── skill-catalog.md  # Complete 60+ skill catalog
├── references/
│   └── superpowers-integration.md  # Superpowers skill integration guide
├── agents/                    # Specialized agents
│   ├── task-executor.md      # Execute single tasks
│   ├── code-reviewer.md      # Review code quality
│   └── verification-agent.md # Run verification pipeline
├── hooks/
│   ├── hooks.json            # Hook configuration
│   ├── stop-hook.sh          # Completion detection
│   └── post-tool.sh          # Auto-verification
├── scripts/
│   ├── detect-project.sh     # Project detection logic
│   ├── setup-worktree.sh     # Create git worktrees
│   ├── run-verification.sh   # Run verification commands
│   ├── merge-branches.sh     # Merge with conflict handling
│   ├── notify.sh             # Cross-platform notifications
│   └── validate-plugin.sh    # Plugin validation
└── README.md
```

## Troubleshooting

### "yq not found" or "jq not found"

```bash
# macOS
brew install yq jq

# Ubuntu/Debian
sudo apt install yq jq
```

### "/auto command not found"

Restart Claude Code to reload plugins:
```bash
exit  # Exit current session
claude  # Start fresh
```

### Plugin not loading

Validate plugin structure:
```bash
~/.claude/plugins/autonomous-dev/scripts/validate-plugin.sh
```

### Worktree issues

Clean up stale worktrees:
```bash
git worktree prune
rm -rf /tmp/auto-worktrees
```

### Verification failing

Check your project profile:
```bash
cat .claude/project-profile.yaml
```

Ensure commands are correct for your project.

### Max iterations reached

The plugin has a safety limit (default 50 iterations). If reached:
1. Check `.claude/auto-progress.yaml` for current state
2. Run `/auto-cancel` to clean up
3. Consider breaking the feature into smaller pieces

## Discipline Enforcement

The plugin enforces these non-negotiable disciplines:

### TDD (Test-Driven Development)
- **No production code without failing test first**
- RED phase: Write ONE minimal failing test
- GREEN phase: Write ONLY enough code to pass
- REFACTOR phase: Clean up while tests pass

### Systematic Debugging
- **No random fixes** - form hypothesis before changing code
- 4-phase protocol: Investigation → Analysis → Hypothesis → Implementation
- Max 3 attempts, then escalate with evidence

### Evidence-Based Verification
- **No claims without fresh command output**
- Gate function: IDENTIFY → RUN → READ → VERIFY → CLAIM
- Red flags: "should", "probably", "seems to"

### YAGNI (You Aren't Gonna Need It)
- Don't add features "just in case"
- Stick to requirements
- Ask before expanding scope

## Advanced Usage

### Custom Verification Commands

Edit `.claude/project-profile.yaml`:
```yaml
commands:
  test: pnpm test -- --coverage
  lint: pnpm lint --fix
  typecheck: tsc --noEmit --strict
```

### Disable Auto-Detection on Session Start

The plugin auto-detects on each session. To skip (use cached profile):
- Profile is cached for 24 hours
- Delete `.claude/project-profile.yaml` to force re-detection

### Manual Worktree Management

```bash
# Create worktree manually
~/.claude/plugins/autonomous-dev/scripts/setup-worktree.sh my-feature

# Merge branches manually
~/.claude/plugins/autonomous-dev/scripts/merge-branches.sh main auto/my-feature
```

## Development

### Validate Plugin

```bash
~/.claude/plugins/autonomous-dev/scripts/validate-plugin.sh
```

### Test with Debug Mode

```bash
claude --debug
# Watch for hook execution and skill loading
```

### Add New Framework Support

1. Edit `scripts/detect-project.sh`
2. Add detection patterns
3. Update `skills/project-detector/references/supported-frameworks.md`

## Contributing

Contributions welcome! Key areas:
- Additional framework detection
- New decomposition patterns
- Improved conflict resolution
- Better verification strategies

## License

MIT
