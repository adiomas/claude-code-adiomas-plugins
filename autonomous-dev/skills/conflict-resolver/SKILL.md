---
name: conflict-resolver
description: >
  This skill should be used when the user asks to "resolve merge conflicts",
  "fix git conflicts", "merge branches", or when autonomous-dev encounters
  merge conflicts during branch integration.
  Intelligently resolves git conflicts or escalates to user when uncertain.
---

# Conflict Resolution Skill

Resolve git merge conflicts intelligently, with safe fallback to user input when uncertain.

## Resolution Protocol

### Step 1: Identify Conflicted Files

List all files with merge conflicts:
```bash
git diff --name-only --diff-filter=U
```

### Step 2: Analyze Each Conflict

For each conflicted file:
1. Read the file with conflict markers
2. Understand what HEAD version accomplishes
3. Understand what incoming version accomplishes
4. Determine resolution strategy

### Step 3: Apply Resolution Strategy

Select strategy based on conflict type:

| Conflict Type | Strategy |
|--------------|----------|
| **Additive changes** | Both add different things → keep both |
| **Same location, different code** | Understand intent, merge logic |
| **Conflicting imports** | Combine import lists |
| **Style conflicts** | Use project lint/format to normalize |

### Step 4: Resolve and Stage

After resolving:
```bash
git add <resolved-file>
```

### Step 5: Complete Merge

Finalize the merge commit:
```bash
git commit --no-edit
```

## Uncertainty Handling

**Critical rule:** Never guess on complex conflicts.

When uncertain about resolution:

1. **Do NOT make assumptions**
2. **Show the conflict to user** with context
3. **Present options:**
   - "Keep HEAD version"
   - "Keep incoming version"
   - "Manual edit needed"
4. **Wait for user decision**

## Common Patterns

### Import Conflicts

Combine import statements:
```javascript
// HEAD
import { ComponentA } from './components';

// Incoming
import { ComponentB } from './components';

// Resolution
import { ComponentA, ComponentB } from './components';
```

### Additive Function Conflicts

Keep both functions when they don't overlap:
```typescript
// HEAD adds functionA
// Incoming adds functionB
// Resolution: keep both
```

### Overlapping Logic

Analyze intent and merge carefully:
- If both change the same logic differently → ask user
- If one extends the other → keep the extension
- If conflicting business logic → ask user

## Safety Rules

1. **Never delete user code** without confirmation
2. **Preserve all functionality** from both branches when possible
3. **When in doubt, ask** - wrong merges are worse than slow merges
4. **Test after resolution** - run verification to catch merge errors

## Additional Resources

### Reference Files

For detailed conflict patterns:
- **`references/conflict-patterns.md`** - 7 common conflict patterns with resolution strategies and auto-resolve safety ratings
