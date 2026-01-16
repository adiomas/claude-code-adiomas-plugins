---
name: task-decomposer
description: >
  This skill should be used when the user asks to "break down this feature",
  "decompose this task", "create task list", "plan implementation steps",
  "identify subtasks", or when planning autonomous execution.
  Converts high-level feature requests into atomic, verifiable tasks with dependencies.
---

# Task Decomposition Skill

Break down feature requests into atomic, verifiable tasks with clear dependencies for parallel execution.

## Core Principles

1. **Atomic Tasks** - Each task completes in one focused session
2. **Clear Boundaries** - Each task modifies a specific set of files
3. **Verifiable** - Each task has explicit "done" criteria
4. **Dependency-Aware** - Mark which tasks depend on others

## Decomposition Process

### Step 1: Understand the Feature

Analyze what the feature needs to accomplish:
- Core functionality required
- User-facing behavior
- Backend/API requirements
- Data model needs

### Step 2: Identify Components

Map the feature to architectural components:

| Component Type | Examples |
|---------------|----------|
| Data models / schemas | Database tables, TypeScript types |
| API endpoints / server functions | REST routes, GraphQL resolvers |
| UI components | React components, pages |
| Business logic / utilities | Helper functions, services |
| Tests | Unit tests, integration tests |

### Step 3: Map Dependencies

Determine execution order based on dependencies:
- Data models are usually independent (can parallelize)
- APIs depend on models
- UI depends on APIs (or can run parallel with mocks)
- Integration tests depend on everything

### Step 4: Create Task List

Format each task with this structure:
```
Task N: [Descriptive Name]
- Depends on: none | [task ids]
- Files: [list of files to create/modify]
- Done when: [specific verification criteria]
- Complexity: S/M/L
```

### Step 5: Identify Parallel Groups

Group tasks by execution phase:
```
Group 1 (Parallel): [independent tasks]
Group 2 (Parallel): [tasks depending on Group 1]
Group 3 (Sequential): [tasks with complex dependencies]
```

## Output Location

Write decomposed tasks to the execution plan at `.claude/plans/auto-{timestamp}.md`.

## Complexity Guidelines

| Size | Scope | Time Estimate |
|------|-------|---------------|
| S | Single file, simple logic | < 15 min |
| M | Multiple files, moderate logic | 15-45 min |
| L | Many files, complex logic | > 45 min |

Prefer breaking L tasks into smaller S/M tasks when possible.

## Additional Resources

### Reference Files

For detailed decomposition patterns:
- **`references/decomposition-patterns.md`** - Common patterns for CRUD, auth, dashboards, integrations

### Example Files

Working examples in `examples/`:
- **`example-decomposition.md`** - Complete example: "Add user registration with email verification"
