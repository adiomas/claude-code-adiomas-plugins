---
name: playwright-mcp
description: >
  Deep E2E testing integration using Playwright MCP server.
  Provides browser automation, screenshot capture, visual comparison,
  and interactive testing through MCP tools.
triggers:
  - work_type: FRONTEND
  - manual: "/e2e"
  - file_pattern: "**/*.tsx"
  - file_pattern: "**/*.vue"
  - file_pattern: "**/*.svelte"
---

# Playwright MCP Integration

Deep browser automation using Playwright MCP server tools.

## MCP Tools Available

When Playwright MCP is configured, these tools become available:

| Tool | Purpose |
|------|---------|
| `mcp__playwright__browser_navigate` | Navigate to URL |
| `mcp__playwright__browser_snapshot` | Get page accessibility snapshot |
| `mcp__playwright__browser_take_screenshot` | Capture screenshot |
| `mcp__playwright__browser_click` | Click element |
| `mcp__playwright__browser_fill_form` | Fill form fields |
| `mcp__playwright__browser_type` | Type text |
| `mcp__playwright__browser_evaluate` | Run JS in page |
| `mcp__playwright__browser_network_requests` | Monitor network |
| `mcp__playwright__browser_console_messages` | Get console logs |

## When to Use

This skill is automatically invoked when:
- `work_type == FRONTEND` in classification
- UI components are modified
- Visual verification is needed
- User invokes `/e2e` command

## Prerequisites

### 1. MCP Server Configuration

Ensure `.mcp.json` includes Playwright:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-playwright"]
    }
  }
}
```

### 2. Dev Server Running

```bash
# Start dev server before E2E tests
npm run dev &
# Wait for ready
npx wait-on http://localhost:3000
```

## E2E Testing Protocol

### Step 1: Navigate to Page

```
Use: mcp__playwright__browser_navigate
URL: http://localhost:3000/target-page
```

### Step 2: Wait for Content

```
Use: mcp__playwright__browser_snapshot
Purpose: Get accessibility tree to verify content loaded
```

### Step 3: Capture Screenshot

```
Use: mcp__playwright__browser_take_screenshot
Options:
  - fullPage: true (capture entire scrollable area)
  - path: .claude/screenshots/page-name.png
```

### Step 4: Interactive Testing

```
Use: mcp__playwright__browser_click
Selector: [data-testid="submit-button"]

Use: mcp__playwright__browser_fill_form
Fields:
  - email: test@example.com
  - password: secret123
```

## Visual Comparison Workflow

### Before Implementation

1. Navigate to affected pages
2. Capture baseline screenshots
3. Store in `.claude/screenshots/baseline/`

### After Implementation

1. Navigate to same pages
2. Capture current screenshots
3. Compare with baselines
4. Report differences

### Comparison Output

```
╔═══════════════════════════════════════════════════════════════╗
║  VISUAL COMPARISON RESULTS                                     ║
╠═══════════════════════════════════════════════════════════════╣
║                                                                 ║
║  Page: /dashboard                                              ║
║  Baseline: .claude/screenshots/baseline/dashboard.png          ║
║  Current:  .claude/screenshots/current/dashboard.png           ║
║                                                                 ║
║  Pixel Difference: 2.3%                                        ║
║  Threshold: 5%                                                 ║
║  Status: ✅ WITHIN TOLERANCE                                   ║
║                                                                 ║
║  Changed Areas:                                                ║
║  - Header navigation (expected - new button added)             ║
║  - Sidebar width (expected - layout change)                    ║
║                                                                 ║
╚═══════════════════════════════════════════════════════════════╝
```

## Responsive Testing

Test across multiple viewport sizes:

```
Viewports to test:
┌────────────────────────────────────┐
│ mobile:  375 x 667  (iPhone SE)    │
│ tablet:  768 x 1024 (iPad)         │
│ desktop: 1280 x 800 (Laptop)       │
│ wide:    1920 x 1080 (Monitor)     │
└────────────────────────────────────┘

For each viewport:
1. mcp__playwright__browser_resize
2. mcp__playwright__browser_navigate
3. mcp__playwright__browser_take_screenshot
```

## Form Testing Protocol

### Test Form Submission

```
1. Navigate: mcp__playwright__browser_navigate
   URL: /signup

2. Fill Form: mcp__playwright__browser_fill_form
   Fields:
     - name: Test User
     - email: test@example.com
     - password: SecurePass123

3. Submit: mcp__playwright__browser_click
   Selector: button[type="submit"]

4. Verify: mcp__playwright__browser_snapshot
   Check: Success message visible
```

### Test Form Validation

```
1. Navigate: mcp__playwright__browser_navigate
   URL: /login

2. Submit Empty: mcp__playwright__browser_click
   Selector: button[type="submit"]

3. Verify Errors: mcp__playwright__browser_snapshot
   Check: Error messages for required fields

4. Fill Invalid: mcp__playwright__browser_fill_form
   Fields:
     - email: invalid-email

5. Verify: mcp__playwright__browser_snapshot
   Check: Email validation error shown
```

## Network Monitoring

Monitor API calls during interactions:

```
1. Start Monitoring: mcp__playwright__browser_network_requests

2. Trigger Action: mcp__playwright__browser_click
   Selector: [data-testid="load-data"]

3. Check Requests:
   - Expected: GET /api/data
   - Status: 200 OK
   - Response time: < 500ms
```

## Console Error Detection

Check for JavaScript errors:

```
1. Navigate: mcp__playwright__browser_navigate
   URL: /complex-page

2. Interact: mcp__playwright__browser_click
   Selector: [data-testid="trigger-error"]

3. Check Console: mcp__playwright__browser_console_messages

4. Report:
   - Errors: 0 (expected)
   - Warnings: 2 (review needed)
```

## Integration with Autonomous Workflow

### In Phase 6 (Verification)

When `work_type == FRONTEND`:

```markdown
## 6.1.3 Visual Verification (FRONTEND)

1. **Start Dev Server**
   ```bash
   npm run dev &
   npx wait-on http://localhost:3000
   ```

2. **Capture Current State**
   - Navigate to affected pages
   - Take screenshots at all viewports
   - Run interactive tests

3. **Compare with Baseline**
   - Calculate pixel differences
   - Flag changes > threshold

4. **Report Results**
   - Include screenshots in evidence
   - Note intentional vs unexpected changes
```

### Evidence Format

```yaml
visual_verification:
  pages_tested: 5
  viewports_tested: 4
  screenshots_captured: 20

  results:
    - page: /dashboard
      status: pass
      pixel_diff: 0.5%

    - page: /login
      status: pass
      pixel_diff: 0.0%

    - page: /profile
      status: warning
      pixel_diff: 8.2%
      note: "Intentional redesign"

  interactive_tests:
    - name: "Login flow"
      status: pass

    - name: "Form validation"
      status: pass

  console_errors: 0
  network_failures: 0
```

## Error Handling

### Browser Won't Launch

```
Error: Browser failed to launch
Fix: Ensure Playwright is installed
     npx playwright install chromium
```

### Selector Not Found

```
Error: Element not found: [data-testid="missing"]
Fix:
  1. Check selector syntax
  2. Verify element exists in DOM
  3. Wait for dynamic content:
     mcp__playwright__browser_wait_for
```

### Screenshot Timeout

```
Error: Screenshot timeout
Fix:
  1. Increase timeout
  2. Wait for specific element
  3. Check page load status
```

## Best Practices

### 1. Use data-testid Attributes

```html
<!-- Good -->
<button data-testid="submit-form">Submit</button>

<!-- Avoid -->
<button class="btn-primary">Submit</button>
```

### 2. Wait for Content

Always wait for content before screenshots:

```
mcp__playwright__browser_snapshot  # Get accessibility tree first
mcp__playwright__browser_take_screenshot  # Then capture
```

### 3. Organize Screenshots

```
.claude/screenshots/
├── baseline/           # Reference images
│   ├── desktop/
│   ├── tablet/
│   └── mobile/
├── current/            # Current run
└── diff/               # Visual differences
```

### 4. Report Intentional Changes

When UI changes are intentional:

```
Visual diff detected: 15.2%
This is EXPECTED because: "Added new sidebar navigation"
Action: Update baseline after review
```

## Cleanup

After E2E testing:

```bash
# Stop dev server
kill $DEV_PID

# Archive screenshots
mkdir -p .claude/screenshots/archive/$(date +%Y%m%d)
mv .claude/screenshots/current/* .claude/screenshots/archive/$(date +%Y%m%d)/
```

## Related Skills

- `e2e-validator` - Original E2E skill (non-MCP)
- `verification-runner` - Overall verification orchestration
- `ai-code-quality` - Code quality analysis
