#!/bin/bash
# Validate autonomous-dev plugin structure and configuration
set -euo pipefail

PLUGIN_ROOT="${1:-$(dirname "$(dirname "$(realpath "$0")")")}"

echo "=== Autonomous-Dev Plugin Validator ==="
echo "Plugin root: $PLUGIN_ROOT"
echo ""

ERRORS=0
WARNINGS=0

# Helper functions
error() {
    echo "❌ ERROR: $1"
    ((ERRORS++))
}

warn() {
    echo "⚠️  WARNING: $1"
    ((WARNINGS++))
}

pass() {
    echo "✅ $1"
}

# Check plugin manifest
echo "--- Checking Plugin Manifest ---"
if [[ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]]; then
    pass "plugin.json exists"

    # Validate JSON
    if jq empty "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null; then
        pass "plugin.json is valid JSON"

        # Check required fields
        NAME=$(jq -r '.name // ""' "$PLUGIN_ROOT/.claude-plugin/plugin.json")
        if [[ -n "$NAME" ]]; then
            pass "Plugin name: $NAME"
        else
            error "Plugin name is missing"
        fi
    else
        error "plugin.json is not valid JSON"
    fi
else
    error "plugin.json not found at .claude-plugin/plugin.json"
fi

echo ""
echo "--- Checking Skills ---"
SKILL_COUNT=0
if [[ -d "$PLUGIN_ROOT/skills" ]]; then
    for skill_dir in "$PLUGIN_ROOT/skills"/*/; do
        if [[ -d "$skill_dir" ]]; then
            skill_name=$(basename "$skill_dir")

            if [[ -f "$skill_dir/SKILL.md" ]]; then
                pass "Skill '$skill_name' has SKILL.md"
                ((SKILL_COUNT++))

                # Check for description with trigger phrases
                if grep -q "This skill should be used when" "$skill_dir/SKILL.md"; then
                    pass "  - Has trigger phrases"
                else
                    warn "  - Missing trigger phrases in description"
                fi

                # Check for references directory
                if [[ -d "$skill_dir/references" ]]; then
                    ref_count=$(find "$skill_dir/references" -name "*.md" | wc -l | tr -d ' ')
                    pass "  - Has references/ ($ref_count files)"
                fi
            else
                error "Skill '$skill_name' missing SKILL.md"
            fi
        fi
    done
    echo "Total skills: $SKILL_COUNT"
else
    warn "No skills directory found"
fi

echo ""
echo "--- Checking Commands ---"
CMD_COUNT=0
if [[ -d "$PLUGIN_ROOT/commands" ]]; then
    for cmd_file in "$PLUGIN_ROOT/commands"/*.md; do
        if [[ -f "$cmd_file" ]]; then
            cmd_name=$(basename "$cmd_file" .md)
            pass "Command: $cmd_name"
            ((CMD_COUNT++))
        fi
    done
    echo "Total commands: $CMD_COUNT"
else
    warn "No commands directory found"
fi

echo ""
echo "--- Checking Agents ---"
AGENT_COUNT=0
if [[ -d "$PLUGIN_ROOT/agents" ]]; then
    for agent_file in "$PLUGIN_ROOT/agents"/*.md; do
        if [[ -f "$agent_file" ]]; then
            agent_name=$(basename "$agent_file" .md)

            # Check for required fields
            if grep -q "^model:" "$agent_file" && grep -q "^color:" "$agent_file"; then
                pass "Agent: $agent_name"
                ((AGENT_COUNT++))

                # Check for examples in description
                if grep -q "<example>" "$agent_file"; then
                    pass "  - Has triggering examples"
                else
                    warn "  - Missing <example> blocks"
                fi
            else
                error "Agent '$agent_name' missing required fields (model, color)"
            fi
        fi
    done
    echo "Total agents: $AGENT_COUNT"
else
    warn "No agents directory found"
fi

echo ""
echo "--- Checking Hooks ---"
if [[ -f "$PLUGIN_ROOT/hooks/hooks.json" ]]; then
    pass "hooks.json exists"

    # Validate JSON
    if jq empty "$PLUGIN_ROOT/hooks/hooks.json" 2>/dev/null; then
        pass "hooks.json is valid JSON"

        # Check for proper format (event-keyed)
        if jq -e '.hooks.SessionStart or .hooks.Stop or .hooks.PreToolUse or .hooks.PostToolUse' "$PLUGIN_ROOT/hooks/hooks.json" >/dev/null 2>&1; then
            pass "hooks.json uses event-keyed format"
        else
            warn "hooks.json might not use correct event-keyed format"
        fi

        # Check for CLAUDE_PLUGIN_ROOT usage
        if grep -q 'CLAUDE_PLUGIN_ROOT' "$PLUGIN_ROOT/hooks/hooks.json"; then
            pass "Uses \${CLAUDE_PLUGIN_ROOT} for portability"
        else
            warn "Should use \${CLAUDE_PLUGIN_ROOT} for portable paths"
        fi
    else
        error "hooks.json is not valid JSON"
    fi
else
    warn "No hooks.json found"
fi

echo ""
echo "--- Checking Scripts ---"
SCRIPT_COUNT=0
if [[ -d "$PLUGIN_ROOT/scripts" ]]; then
    for script in "$PLUGIN_ROOT/scripts"/*.sh; do
        if [[ -f "$script" ]]; then
            script_name=$(basename "$script")

            # Check if executable or has shebang
            if [[ -x "$script" ]] || head -1 "$script" | grep -q "^#!/"; then
                pass "Script: $script_name"
                ((SCRIPT_COUNT++))
            else
                warn "Script '$script_name' missing shebang or not executable"
            fi
        fi
    done
    echo "Total scripts: $SCRIPT_COUNT"
else
    warn "No scripts directory found"
fi

echo ""
echo "=== Validation Summary ==="
echo "Components: $SKILL_COUNT skills, $CMD_COUNT commands, $AGENT_COUNT agents, $SCRIPT_COUNT scripts"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [[ $ERRORS -eq 0 ]]; then
    echo "✅ Plugin validation PASSED"
    exit 0
else
    echo "❌ Plugin validation FAILED"
    exit 1
fi
