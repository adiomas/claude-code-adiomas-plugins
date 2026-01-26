---
name: supabase-deep
description: >
  Full Supabase workflow automation with TypeScript type generation,
  migration validation, RLS policy testing, and schema synchronization.
  Uses Supabase MCP tools for direct database interaction.
triggers:
  - file_pattern: "*.sql"
  - file_pattern: "**/migrations/*"
  - file_pattern: "**/supabase/**"
  - manual: "/db"
  - manual: "/schema"
---

# Supabase Deep Integration

Comprehensive Supabase workflow automation using MCP tools.

## MCP Tools Available

When Supabase MCP is configured, these tools become available:

| Tool | Purpose |
|------|---------|
| `mcp__supabase__execute_sql` | Run SQL queries |
| `mcp__supabase__list_tables` | List database tables |
| `mcp__supabase__list_extensions` | List PostgreSQL extensions |
| `mcp__supabase__list_migrations` | List applied migrations |
| `mcp__supabase__apply_migration` | Apply new migration |
| `mcp__supabase__get_logs` | Get database logs |
| `mcp__supabase__generate_typescript_types` | Generate TS types |
| `mcp__supabase__get_project` | Get project info |
| `mcp__supabase__search_docs` | Search Supabase docs |

## When to Use

This skill is automatically invoked when:
- SQL files are modified
- Migration files are created/changed
- Supabase config is modified
- User invokes `/db` or `/schema` command
- Database-related errors occur

## Pre-Migration Protocol

### CRITICAL: Always Follow This Order

```
┌─────────────────────────────────────────────────────────────────┐
│                  PRE-MIGRATION CHECKLIST                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. ☐ Backup current schema                                     │
│     → mcp__supabase__execute_sql (pg_dump equivalent)           │
│                                                                  │
│  2. ☐ Generate types BEFORE change                              │
│     → mcp__supabase__generate_typescript_types                  │
│     → Save to .claude/types/before-migration.ts                 │
│                                                                  │
│  3. ☐ Create rollback migration                                 │
│     → Write inverse of intended changes                         │
│     → Store in supabase/migrations/rollback/                    │
│                                                                  │
│  4. ☐ Run on dev branch first                                   │
│     → Create Supabase branch if not exists                      │
│     → Apply migration to branch                                 │
│     → Test thoroughly                                           │
│                                                                  │
│  5. ☐ Merge only after verification                             │
│     → All tests pass                                            │
│     → Types are regenerated                                     │
│     → RLS policies validated                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Schema Change Workflow

### Step 1: Analyze Current Schema

```
Use: mcp__supabase__list_tables

Output:
┌──────────────────────────────────────────────────────────────┐
│ Table           │ Rows    │ Size    │ RLS │ Last Modified    │
├──────────────────────────────────────────────────────────────┤
│ users           │ 1,234   │ 2.1 MB  │ ✓   │ 2026-01-25       │
│ invoices        │ 5,678   │ 15.3 MB │ ✓   │ 2026-01-26       │
│ categories      │ 45      │ 12 KB   │ ✓   │ 2026-01-20       │
└──────────────────────────────────────────────────────────────┘
```

### Step 2: Generate Baseline Types

```
Use: mcp__supabase__generate_typescript_types

Save to: src/types/database.types.ts (existing)
Backup to: .claude/types/pre-change-{timestamp}.ts
```

### Step 3: Create Migration

```sql
-- supabase/migrations/20260126_add_invoice_status.sql

-- Add status column to invoices
ALTER TABLE invoices
ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'
CHECK (status IN ('pending', 'paid', 'cancelled', 'overdue'));

-- Add index for status queries
CREATE INDEX idx_invoices_status ON invoices(status);

-- Update RLS policy
CREATE POLICY "Users can update own invoice status"
ON invoices FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
```

### Step 4: Create Rollback Migration

```sql
-- supabase/migrations/rollback/20260126_add_invoice_status_rollback.sql

-- Remove status column
ALTER TABLE invoices DROP COLUMN status;

-- Remove index
DROP INDEX IF EXISTS idx_invoices_status;

-- Remove RLS policy
DROP POLICY IF EXISTS "Users can update own invoice status" ON invoices;
```

### Step 5: Apply to Dev Branch

```
Use: mcp__supabase__apply_migration
File: supabase/migrations/20260126_add_invoice_status.sql
Branch: dev (or feature branch)
```

### Step 6: Regenerate Types

```
Use: mcp__supabase__generate_typescript_types

Verify new types include:
- invoices.status: 'pending' | 'paid' | 'cancelled' | 'overdue'
```

### Step 7: Update Application Code

```typescript
// Update type imports
import { Database } from '@/types/database.types';

type Invoice = Database['public']['Tables']['invoices']['Row'];

// Invoice now includes status
const invoice: Invoice = {
  id: '...',
  amount: 100,
  status: 'pending', // ✅ Type-safe
};
```

## RLS Policy Testing

### Validate Policies

```sql
-- Test RLS as authenticated user
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "user-123"}';

-- Should return only user's invoices
SELECT * FROM invoices;

-- Should fail for other user's data
UPDATE invoices SET status = 'paid' WHERE user_id != 'user-123';
-- Expected: 0 rows updated (RLS blocks)
```

### Policy Test Output

```
╔═══════════════════════════════════════════════════════════════╗
║  RLS POLICY TEST RESULTS                                       ║
╠═══════════════════════════════════════════════════════════════╣
║                                                                 ║
║  Table: invoices                                               ║
║                                                                 ║
║  ┌────────────────────────────────────────────────────────┐   ║
║  │ Policy                    │ SELECT │ INSERT │ UPDATE │   ║
║  ├────────────────────────────────────────────────────────┤   ║
║  │ Users can view own        │   ✅   │   -    │   -    │   ║
║  │ Users can insert own      │   -    │   ✅   │   -    │   ║
║  │ Users can update own      │   -    │   -    │   ✅   │   ║
║  │ Cross-user access blocked │   ✅   │   ✅   │   ✅   │   ║
║  └────────────────────────────────────────────────────────┘   ║
║                                                                 ║
║  Status: ✅ ALL POLICIES WORKING                               ║
║                                                                 ║
╚═══════════════════════════════════════════════════════════════╝
```

## Type Synchronization

### Auto-Sync Protocol

After any schema change:

1. **Generate Types**
   ```
   Use: mcp__supabase__generate_typescript_types
   Output: src/types/database.types.ts
   ```

2. **Verify Type Compatibility**
   ```bash
   # Run TypeScript compiler
   npx tsc --noEmit

   # Check for type errors in affected files
   ```

3. **Update Affected Code**
   - Find usages of changed types
   - Update to match new schema
   - Add/remove fields as needed

### Type Diff Detection

```
╔═══════════════════════════════════════════════════════════════╗
║  TYPE DIFF: invoices                                           ║
╠═══════════════════════════════════════════════════════════════╣
║                                                                 ║
║  BEFORE:                                                       ║
║  interface Invoice {                                           ║
║    id: string;                                                 ║
║    amount: number;                                             ║
║    user_id: string;                                            ║
║  }                                                             ║
║                                                                 ║
║  AFTER:                                                        ║
║  interface Invoice {                                           ║
║    id: string;                                                 ║
║    amount: number;                                             ║
║    user_id: string;                                            ║
║  + status: 'pending' | 'paid' | 'cancelled' | 'overdue';      ║
║  }                                                             ║
║                                                                 ║
║  Affected files:                                               ║
║  - src/components/InvoiceTable.tsx (line 45, 78)              ║
║  - src/hooks/useInvoices.ts (line 23)                         ║
║  - src/pages/InvoiceList.tsx (line 112)                       ║
║                                                                 ║
╚═══════════════════════════════════════════════════════════════╝
```

## Edge Function Deployment

### Deploy Protocol

```
1. Validate function locally
   supabase functions serve function-name

2. Run tests
   deno test supabase/functions/function-name/

3. Deploy
   Use: mcp__supabase__deploy_edge_function
   Function: function-name

4. Verify deployment
   Use: mcp__supabase__get_edge_function
   Check: Status = active
```

## Error Handling

### Migration Failed

```
Error: Migration failed - constraint violation
Fix:
  1. Check existing data compatibility
  2. Add data migration step before schema change
  3. Use: mcp__supabase__execute_sql to fix data
  4. Retry migration
```

### Type Mismatch

```
Error: Type 'string' is not assignable to type 'Invoice'
Fix:
  1. Regenerate types: mcp__supabase__generate_typescript_types
  2. Update code to match new schema
  3. Run: npx tsc --noEmit
```

### RLS Blocking

```
Error: new row violates RLS policy
Fix:
  1. Check auth context
  2. Verify user_id matches
  3. Review policy conditions
  4. Use: mcp__supabase__execute_sql to debug
```

## Integration with Autonomous Workflow

### In Task Decomposition

When database changes detected:

```yaml
# Auto-added phase for DB work
phases:
  - id: 0
    name: "Database Setup"
    description: "Schema changes, migrations, type sync"
    steps:
      - Backup current schema
      - Generate baseline types
      - Create migration
      - Create rollback
      - Apply to dev branch
      - Regenerate types
      - Update application code
```

### In Verification

```yaml
verification:
  database:
    - migration_applied: true
    - types_regenerated: true
    - rls_policies_tested: true
    - no_type_errors: true
    - rollback_available: true
```

## Best Practices

### 1. Always Create Rollbacks

Every migration MUST have a corresponding rollback:

```
supabase/migrations/
├── 20260126_add_invoice_status.sql
└── rollback/
    └── 20260126_add_invoice_status_rollback.sql
```

### 2. Test RLS Policies

Never assume policies work - always test:

```sql
-- Test as different roles
SET LOCAL role TO anon;
-- Should fail
SELECT * FROM invoices;

SET LOCAL role TO authenticated;
-- Should return filtered data
SELECT * FROM invoices;
```

### 3. Keep Types in Sync

After ANY schema change:

```
mcp__supabase__generate_typescript_types
npx tsc --noEmit
```

### 4. Use Branches for Testing

Never apply migrations directly to production:

```
1. Create branch: mcp__supabase__create_branch
2. Apply migration to branch
3. Test thoroughly
4. Merge: mcp__supabase__merge_branch
```

### 5. Document Schema Changes

In migration files:

```sql
-- Migration: Add invoice status
-- Author: Autonomous Dev
-- Date: 2026-01-26
-- Reason: Track invoice payment status
-- Rollback: rollback/20260126_add_invoice_status_rollback.sql
-- Affected: InvoiceTable, InvoiceList, useInvoices
```

## Related Skills

- `schema-validator` agent - Validates TypeScript matches database
- `verification-runner` - Overall verification orchestration
- `project-detector` - Detects Supabase in project stack
