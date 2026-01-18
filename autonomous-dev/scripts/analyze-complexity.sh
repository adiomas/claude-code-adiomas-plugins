#!/bin/bash
# Smart Ralph - Complexity Analyzer
# Analyzes task prompt and outputs complexity score (1-5) with mode selection

set -e

PROMPT="${1:-}"

if [[ -z "$PROMPT" ]]; then
    echo '{"error": "No prompt provided", "score": 2, "mode": "DIRECT", "reasoning": "Default fallback"}'
    exit 0
fi

# Convert to lowercase for matching
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Initialize score
SCORE=2

# Positive signals (increase complexity)
POSITIVE_SIGNALS=(
    "full:1"
    "complete:1"
    "entire:1"
    "whole:1"
    "system:1"
    "dashboard:1"
    "authentication:1"
    "auth:1"
    "database:1"
    "schema:1"
    "payment:1"
    "billing:1"
    "e-commerce:1"
    "ecommerce:1"
    "admin:0.5"
    "email:0.5"
    "notification:0.5"
    "api:0.5"
    "backend:0.5"
    "frontend:0.5"
)

# Negative signals (decrease complexity)
NEGATIVE_SIGNALS=(
    "simple:-1"
    "quick:-1"
    "just:-1"
    "only:-1"
    "small:-1"
    "minor:-1"
    "fix:-1"
    "typo:-1"
    "rename:-1"
    "update version:-1"
    "button:-0.5"
    "component:-0.5"
)

DETECTED_POSITIVE=""
DETECTED_NEGATIVE=""

# Check positive signals
for signal_pair in "${POSITIVE_SIGNALS[@]}"; do
    signal="${signal_pair%%:*}"
    modifier="${signal_pair##*:}"
    if [[ "$PROMPT_LOWER" == *"$signal"* ]]; then
        SCORE=$(echo "$SCORE + $modifier" | bc)
        DETECTED_POSITIVE="$DETECTED_POSITIVE $signal(+$modifier)"
    fi
done

# Check negative signals
for signal_pair in "${NEGATIVE_SIGNALS[@]}"; do
    signal="${signal_pair%%:*}"
    modifier="${signal_pair##*:}"
    if [[ "$PROMPT_LOWER" == *"$signal"* ]]; then
        SCORE=$(echo "$SCORE + $modifier" | bc)
        DETECTED_NEGATIVE="$DETECTED_NEGATIVE $signal($modifier)"
    fi
done

# Count feature mentions (commas and "and" often indicate multiple features)
FEATURE_COUNT=$(echo "$PROMPT_LOWER" | grep -o ',' | wc -l | tr -d ' ')
AND_COUNT=$(echo "$PROMPT_LOWER" | grep -o ' and ' | wc -l | tr -d ' ')
TOTAL_FEATURES=$((FEATURE_COUNT + AND_COUNT))

if [[ $TOTAL_FEATURES -gt 1 ]]; then
    SCORE=$(echo "$SCORE + ($TOTAL_FEATURES * 0.5)" | bc)
    DETECTED_POSITIVE="$DETECTED_POSITIVE features(+$TOTAL_FEATURES*0.5)"
fi

# Round and clamp score to 1-5
SCORE_INT=$(printf "%.0f" "$SCORE")
if [[ $SCORE_INT -lt 1 ]]; then
    SCORE_INT=1
elif [[ $SCORE_INT -gt 5 ]]; then
    SCORE_INT=5
fi

# Determine mode
if [[ $SCORE_INT -le 2 ]]; then
    MODE="DIRECT"
else
    MODE="ORCHESTRATED"
fi

# Build reasoning
REASONING="Base score 2"
if [[ -n "$DETECTED_POSITIVE" ]]; then
    REASONING="$REASONING, positive signals:$DETECTED_POSITIVE"
fi
if [[ -n "$DETECTED_NEGATIVE" ]]; then
    REASONING="$REASONING, negative signals:$DETECTED_NEGATIVE"
fi
REASONING="$REASONING -> final score $SCORE_INT"

# Output JSON
cat << EOF
{
    "score": $SCORE_INT,
    "mode": "$MODE",
    "reasoning": "$REASONING",
    "raw_score": $SCORE,
    "signals": {
        "positive": "$(echo $DETECTED_POSITIVE | xargs)",
        "negative": "$(echo $DETECTED_NEGATIVE | xargs)",
        "feature_count": $TOTAL_FEATURES
    }
}
EOF
