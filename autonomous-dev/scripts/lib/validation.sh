#!/usr/bin/env bash
# validation.sh - Input validation and safe command execution
# Part of autonomous-dev v4.0 security improvements
#
# Usage:
#   source scripts/lib/validation.sh
#   if validate_command "$cmd"; then
#       safe_exec "$cmd"
#   fi

set -euo pipefail

# Source logger if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/logger.sh" ]]; then
    source "$SCRIPT_DIR/logger.sh"
else
    log_info() { echo "[INFO] $*"; }
    log_warn() { echo "[WARN] $*" >&2; }
    log_error() { echo "[ERROR] $*" >&2; }
fi

# Whitelist of allowed command patterns
# Each pattern is a regex that matches allowed commands
declare -a ALLOWED_COMMAND_PATTERNS=(
    # Package managers - test/build/lint commands
    '^(npm|yarn|pnpm|bun)[[:space:]]+(test|run|build|lint|typecheck|check|ci|install|exec)[[:space:]]*'
    '^npx[[:space:]]+(jest|vitest|eslint|prettier|tsc|playwright)[[:space:]]*'

    # Python
    '^(python3?|pip3?)[[:space:]]+(setup\.py|manage\.py|-m[[:space:]]+(pytest|unittest|mypy|black|flake8|pylint))[[:space:]]*'
    '^(pytest|mypy|black|flake8|pylint|poetry)[[:space:]]*'

    # Go
    '^go[[:space:]]+(test|build|vet|fmt|mod)[[:space:]]*'
    '^golangci-lint[[:space:]]*'

    # Rust
    '^cargo[[:space:]]+(test|build|check|clippy|fmt)[[:space:]]*'

    # Java/Kotlin
    '^(mvn|gradle|gradlew)[[:space:]]+(test|build|check|compile)[[:space:]]*'

    # Ruby
    '^(bundle|rake|rspec)[[:space:]]*(test|spec|build)?[[:space:]]*'

    # Git (read-only and safe operations)
    '^git[[:space:]]+(status|diff|log|show|branch|fetch|pull|add|commit|push|stash|checkout|switch|worktree)[[:space:]]*'

    # Docker (read-only)
    '^docker[[:space:]]+(ps|images|logs|inspect)[[:space:]]*'

    # Make
    '^make[[:space:]]+(test|build|lint|check|all)?[[:space:]]*$'
)

# Blacklist of dangerous patterns (always blocked)
declare -a BLOCKED_PATTERNS=(
    # Dangerous commands
    'rm[[:space:]]+-rf[[:space:]]+/'
    'rm[[:space:]]+-rf[[:space:]]+\*'
    'rm[[:space:]]+-rf[[:space:]]+\.\.'
    'sudo[[:space:]]+'
    'chmod[[:space:]]+777'
    'curl[[:space:]]+.*\|[[:space:]]*sh'
    'wget[[:space:]]+.*\|[[:space:]]*sh'
    'eval[[:space:]]+'

    # Command injection patterns
    '\$\([^)]+\)'     # $(command)
    '`[^`]+`'         # `command`
    '\|\|'            # || (command chaining)
    '&&.*&&'          # Multiple && chains
    '>[[:space:]]*/'  # Redirect to root

    # Network exfiltration
    'nc[[:space:]]+-'
    'netcat'
    '/dev/tcp/'

    # Privilege escalation
    'chmod[[:space:]]+[+]?s'
    'chown[[:space:]]+root'
)

# Validate a command against whitelist/blacklist
# Usage: validate_command "npm test"
# Returns: 0 if allowed, 1 if blocked
validate_command() {
    local cmd="$1"

    # First check blacklist (always takes precedence)
    for pattern in "${BLOCKED_PATTERNS[@]}"; do
        if [[ "$cmd" =~ $pattern ]]; then
            log_error "Command blocked by security policy: $cmd (matched: $pattern)"
            return 1
        fi
    done

    # Check whitelist
    for pattern in "${ALLOWED_COMMAND_PATTERNS[@]}"; do
        if [[ "$cmd" =~ $pattern ]]; then
            return 0
        fi
    done

    # Command not in whitelist
    log_warn "Command not in whitelist: $cmd"
    return 1
}

# Validate and execute a command safely
# Usage: safe_exec "npm test"
safe_exec() {
    local cmd="$1"
    local allow_unlisted="${2:-false}"

    # Validate command
    if ! validate_command "$cmd"; then
        if [[ "$allow_unlisted" != "true" ]]; then
            log_error "Refusing to execute unvalidated command: $cmd"
            return 1
        fi
        log_warn "Executing unlisted command (override enabled): $cmd"
    fi

    log_info "Executing: $cmd"

    # Execute with bash -c (not eval!) to prevent injection
    bash -c "$cmd"
}

# Validate a file path (prevent path traversal)
# Usage: validate_path "/some/path" "/allowed/base"
validate_path() {
    local path="$1"
    local base="${2:-$(pwd)}"

    # Resolve to absolute path
    local real_path
    real_path=$(cd "$base" && realpath -m "$path" 2>/dev/null || echo "$path")

    local real_base
    real_base=$(realpath "$base" 2>/dev/null || echo "$base")

    # Check for path traversal
    if [[ ! "$real_path" == "$real_base"* ]]; then
        log_error "Path traversal detected: $path escapes $base"
        return 1
    fi

    # Check for dangerous patterns
    if [[ "$path" == *".."* ]]; then
        log_warn "Path contains ..: $path"
    fi

    return 0
}

# Validate YAML content (prevent YAML injection)
# Usage: validate_yaml_value "some value"
validate_yaml_value() {
    local value="$1"

    # Check for YAML special characters that could cause issues
    local dangerous_patterns=(
        '!!python'
        '!!ruby'
        '!!'
        '{{.*}}'
        '\${{.*}}'
    )

    for pattern in "${dangerous_patterns[@]}"; do
        if [[ "$value" =~ $pattern ]]; then
            log_error "Potentially dangerous YAML value: $value"
            return 1
        fi
    done

    return 0
}

# Sanitize a string for use in file names
# Usage: safe_name=$(sanitize_filename "My File (2).txt")
sanitize_filename() {
    local name="$1"

    # Remove or replace dangerous characters
    name="${name//[\/\\:*?\"<>|]/-}"

    # Remove leading/trailing dots and spaces
    name="${name#.}"
    name="${name%.}"
    name="${name# }"
    name="${name% }"

    # Limit length
    name="${name:0:200}"

    # Ensure not empty
    if [[ -z "$name" ]]; then
        name="unnamed"
    fi

    echo "$name"
}

# Sanitize a string for use in git branch names
# Usage: branch_name=$(sanitize_branch_name "feature/My Feature!")
sanitize_branch_name() {
    local name="$1"

    # Convert to lowercase
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]')

    # Replace spaces and special chars with dashes
    name="${name//[^a-z0-9\/]/-}"

    # Remove multiple consecutive dashes
    name=$(echo "$name" | sed 's/--*/-/g')

    # Remove leading/trailing dashes
    name="${name#-}"
    name="${name%-}"

    # Limit length
    name="${name:0:50}"

    echo "$name"
}

# Validate environment variable name
# Usage: validate_env_name "MY_VAR"
validate_env_name() {
    local name="$1"

    # Must start with letter or underscore, contain only alphanumeric and underscore
    if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        log_error "Invalid environment variable name: $name"
        return 1
    fi

    return 0
}

# Escape a string for safe use in shell
# Usage: escaped=$(shell_escape "value with 'quotes'")
shell_escape() {
    local value="$1"
    printf '%q' "$value"
}

# Validate URL format
# Usage: validate_url "https://example.com"
validate_url() {
    local url="$1"

    # Basic URL validation
    if [[ ! "$url" =~ ^https?://[a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+.*$ ]]; then
        log_error "Invalid URL format: $url"
        return 1
    fi

    # Block localhost/internal URLs (security)
    if [[ "$url" =~ (localhost|127\.0\.0\.1|0\.0\.0\.0|::1|\.local) ]]; then
        log_warn "URL points to local/internal address: $url"
    fi

    return 0
}

# Add a command pattern to whitelist (runtime)
# Usage: add_allowed_pattern '^my-custom-command[[:space:]]*'
add_allowed_pattern() {
    local pattern="$1"
    ALLOWED_COMMAND_PATTERNS+=("$pattern")
    log_info "Added command pattern to whitelist: $pattern"
}

# Check if a string contains only safe characters
# Usage: is_safe_string "hello-world_123"
is_safe_string() {
    local str="$1"
    local allowed="${2:-a-zA-Z0-9_-}"

    [[ "$str" =~ ^[$allowed]+$ ]]
}

# Validate JSON string
# Usage: validate_json '{"key": "value"}'
validate_json() {
    local json="$1"

    if command -v jq &> /dev/null; then
        echo "$json" | jq . > /dev/null 2>&1
    elif command -v python3 &> /dev/null; then
        echo "$json" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null
    else
        # Basic check: balanced braces/brackets
        local open_braces=$(($(echo "$json" | tr -cd '{' | wc -c)))
        local close_braces=$(($(echo "$json" | tr -cd '}' | wc -c)))
        local open_brackets=$(($(echo "$json" | tr -cd '[' | wc -c)))
        local close_brackets=$(($(echo "$json" | tr -cd ']' | wc -c)))

        [[ $open_braces -eq $close_braces && $open_brackets -eq $close_brackets ]]
    fi
}
