---
name: project-detector
description: >
  This skill should be used when the user asks to "detect project type",
  "analyze this project", "create project profile", "what tech stack is this",
  "scan project structure", or when autonomous development starts in a new codebase.
  Detects package.json, pyproject.toml, go.mod, Cargo.toml to identify the technology stack.
---

# Project Detection Skill

Analyze the current directory and create `.claude/project-profile.yaml` to enable autonomous development workflows.

## Protocol

### Step 1: Check Existing Profile

Check if `.claude/project-profile.yaml` exists:
- If exists and is less than 1 day old → read and summarize it
- Otherwise → create or update it

### Step 2: Detect Package Manager and Language

Scan for project files:
```bash
ls package.json pyproject.toml go.mod Cargo.toml pom.xml 2>/dev/null
```

Identify the primary language based on which file exists.

### Step 3: Detect Framework

Look for framework-specific config files:

| Config File | Framework |
|-------------|-----------|
| `next.config.*` | Next.js |
| `vite.config.*` | Vite |
| `nuxt.config.*` | Nuxt |
| `astro.config.*` | Astro |
| `settings.py` + `manage.py` | Django |
| `Cargo.toml` with actix/axum | Rust web |

### Step 4: Extract Commands

Parse package.json scripts or detect standard commands:
- `test` - Testing command
- `lint` - Linting command
- `typecheck` - Type checking command
- `build` - Build command
- `dev` - Development server

### Step 5: Identify Directory Patterns

Scan directory structure to find:
- Component locations
- API route locations
- Test file locations
- Source code organization

### Step 6: Write Profile

Write detected information to `.claude/project-profile.yaml` with structure:
```yaml
project:
  name: ""
  type: ""  # frontend, backend, fullstack
stack:
  language: ""
  framework: ""
commands:
  test: ""
  lint: ""
  typecheck: ""
  build: ""
verification:
  required: []
  optional: []
```

### Step 7: Summarize

Present detected configuration to the user for confirmation.

## Additional Resources

### Reference Files

For detailed framework detection patterns:
- **`references/supported-frameworks.md`** - Complete list of supported frameworks with detection patterns

### Example Files

Working examples in `examples/`:
- **`project-profile-nextjs.yaml`** - Example profile for a Next.js project

### Script Reference

Run the detection script directly:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/detect-project.sh
```
