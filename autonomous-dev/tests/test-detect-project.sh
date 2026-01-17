#!/bin/bash
# Test: detect-project.sh functionality
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Testing detect-project.sh ==="

# Test 1: Script exists and is executable
echo -n "Test 1: Script exists and is executable... "
if [[ -x "$PLUGIN_ROOT/scripts/detect-project.sh" ]]; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

# Test 2: Has shebang
echo -n "Test 2: Has proper shebang... "
if head -1 "$PLUGIN_ROOT/scripts/detect-project.sh" | grep -q "^#!/bin/bash"; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

# Test 3: Has set -euo pipefail
echo -n "Test 3: Has set -euo pipefail... "
if grep -q "^set -euo pipefail" "$PLUGIN_ROOT/scripts/detect-project.sh"; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

# Test 4: No bc usage (should use awk)
echo -n "Test 4: No bc usage... "
if ! grep -q '\bbc\b' "$PLUGIN_ROOT/scripts/detect-project.sh"; then
    echo "PASS"
else
    echo "FAIL - should use awk instead of bc"
    exit 1
fi

# Test 5: Create temp project and detect
echo -n "Test 5: Detects Node.js project... "
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

cat > "$TEMP_DIR/package.json" << 'EOF'
{
  "name": "test-project",
  "version": "1.0.0",
  "scripts": {
    "test": "vitest",
    "lint": "eslint .",
    "build": "vite build"
  }
}
EOF

# Run detection in temp directory
cd "$TEMP_DIR"
if bash "$PLUGIN_ROOT/scripts/detect-project.sh" > /dev/null 2>&1; then
    if [[ -f ".claude/project-profile.yaml" ]]; then
        echo "PASS"
    else
        echo "FAIL - profile not created"
        exit 1
    fi
else
    echo "FAIL - script error"
    exit 1
fi

echo ""
echo "=== All detect-project.sh tests passed ==="
