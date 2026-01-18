#!/usr/bin/env bash
# pii-filter.sh - Bash wrapper for PII tokenization
# Anthropic Best Practice: Filter PII from data before model processing
#
# Usage:
#   echo "data with email@example.com" | ./pii-filter.sh tokenize
#   echo "[EMAIL_1]" | ./pii-filter.sh detokenize
#   ./pii-filter.sh tokenize "Contact: user@domain.com, Phone: 091-123-4567"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PII_TOKENIZER="$SCRIPT_DIR/pii-tokenizer.ts"

# Token storage for session
TOKEN_FILE="/tmp/pii-tokens-$$.json"

# Cleanup on exit
cleanup() {
    rm -f "$TOKEN_FILE"
}
trap cleanup EXIT

# Check for deno or ts-node
run_typescript() {
    if command -v deno &> /dev/null; then
        deno run --allow-read --allow-write "$PII_TOKENIZER" "$@"
    elif command -v ts-node &> /dev/null; then
        ts-node "$PII_TOKENIZER" "$@"
    elif command -v npx &> /dev/null; then
        npx ts-node "$PII_TOKENIZER" "$@"
    else
        # Fallback: simple sed-based tokenization
        fallback_tokenize "$@"
    fi
}

# Fallback tokenization using sed (less sophisticated)
fallback_tokenize() {
    local action="$1"
    shift
    local data="$*"

    if [[ "$action" == "tokenize" ]]; then
        # Simple pattern replacement
        echo "$data" | \
            sed -E 's/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/[EMAIL]/g' | \
            sed -E 's/\+?[0-9]{1,3}[-. ]?\(?[0-9]{2,4}\)?[-. ]?[0-9]{3,4}[-. ]?[0-9]{3,4}/[PHONE]/g' | \
            sed -E 's/\b[0-9]{11}\b/[OIB]/g' | \
            sed -E 's/\b([0-9]{4}[-. ]?){3,4}[0-9]{1,4}\b/[CARD]/g' | \
            sed -E 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}\b/[IP]/g'
    else
        echo "Detokenize not available in fallback mode" >&2
        echo "$data"
    fi
}

# Main command handling
case "${1:-help}" in
    "tokenize")
        shift
        if [[ -p /dev/stdin ]]; then
            # Read from pipe
            data=$(cat)
            run_typescript tokenize "$data"
        elif [[ $# -gt 0 ]]; then
            # Read from arguments
            run_typescript tokenize "$@"
        else
            echo "Usage: $0 tokenize <data>" >&2
            echo "   or: echo 'data' | $0 tokenize" >&2
            exit 1
        fi
        ;;

    "detokenize")
        shift
        if [[ -p /dev/stdin ]]; then
            data=$(cat)
            run_typescript detokenize "$data"
        elif [[ $# -gt 0 ]]; then
            run_typescript detokenize "$@"
        else
            echo "Usage: $0 detokenize <data>" >&2
            exit 1
        fi
        ;;

    "test")
        echo "Testing PII tokenization..."
        echo ""

        TEST_DATA="Contact John at john.doe@example.com or call +385-91-123-4567. OIB: 12345678901. IP: 192.168.1.1"
        echo "Original: $TEST_DATA"
        echo ""

        TOKENIZED=$(echo "$TEST_DATA" | "$0" tokenize)
        echo "Tokenized: $TOKENIZED"
        echo ""

        # Check if PII was removed
        if echo "$TOKENIZED" | grep -qE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"; then
            echo "❌ FAIL: Email not tokenized"
            exit 1
        fi

        if echo "$TOKENIZED" | grep -qE "\+?[0-9]{1,3}[-. ]?\(?[0-9]{2,4}\)?[-. ]?[0-9]{3,4}"; then
            echo "❌ FAIL: Phone not tokenized"
            exit 1
        fi

        echo "✅ PASS: PII successfully tokenized"
        ;;

    "help"|*)
        cat << 'EOF'
PII Filter - Tokenize personal data before model processing

Usage:
  pii-filter.sh tokenize <data>       Replace PII with tokens
  pii-filter.sh detokenize <data>     Restore original PII
  pii-filter.sh test                  Run self-test

Supported PII types:
  - Email addresses    → [EMAIL_N]
  - Phone numbers      → [PHONE_N]
  - OIB (11 digits)    → [OIB_N]
  - Credit cards       → [CARD_N]
  - IP addresses       → [IP_N]

Examples:
  echo "Contact: user@example.com" | ./pii-filter.sh tokenize
  ./pii-filter.sh tokenize "Call 091-123-4567"

Integration:
  # Before sending to model
  SAFE_DATA=$(./pii-filter.sh tokenize "$USER_DATA")

  # After receiving from model
  RESTORED=$(./pii-filter.sh detokenize "$MODEL_OUTPUT")
EOF
        ;;
esac
