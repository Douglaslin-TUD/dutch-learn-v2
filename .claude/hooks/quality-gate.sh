#!/bin/bash
# TaskCompleted Hook - Quality Gate
# Runs tests before allowing a task to be marked as completed.
# Exit code 0 = allow completion
# Exit code 2 = block completion and send feedback to agent

set -euo pipefail

INPUT=$(cat)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // "unknown"')
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // "unknown"')

PROJECT_DIR="/data/AI  Tools/dutch-learn-v2"

# Determine which test suite to run based on changed files
DESKTOP_CHANGED=false
MOBILE_CHANGED=false

# Check git diff for changed files
CHANGED_FILES=$(cd "$PROJECT_DIR" && git diff --name-only HEAD 2>/dev/null || echo "")

if echo "$CHANGED_FILES" | grep -q "^desktop/"; then
    DESKTOP_CHANGED=true
fi

if echo "$CHANGED_FILES" | grep -q "^mobile/"; then
    MOBILE_CHANGED=true
fi

# If no git changes detected, check both (task may have just been created)
if [ "$DESKTOP_CHANGED" = false ] && [ "$MOBILE_CHANGED" = false ]; then
    DESKTOP_CHANGED=true
    MOBILE_CHANGED=true
fi

FAILURES=""

# Run desktop tests if desktop files changed
if [ "$DESKTOP_CHANGED" = true ]; then
    if [ -d "$PROJECT_DIR/desktop/tests" ]; then
        echo "Running desktop tests..." >&2
        cd "$PROJECT_DIR/desktop"
        if ! source ../venv/bin/activate 2>/dev/null; then
            echo "Warning: Could not activate venv, skipping desktop tests" >&2
        else
            TEST_OUTPUT=$(python -m pytest tests/ -q --tb=short --maxfail=5 2>&1) || true
            if echo "$TEST_OUTPUT" | grep -qE "failed|error"; then
                FAILURES="${FAILURES}Desktop tests failed:\n${TEST_OUTPUT}\n\n"
            fi
        fi
    fi
fi

# Run mobile tests if mobile files changed
if [ "$MOBILE_CHANGED" = true ]; then
    if [ -d "$PROJECT_DIR/mobile/test" ]; then
        echo "Running mobile tests..." >&2
        export PATH="/home/peng-lin/flutter/bin:/usr/bin:$PATH"
        cd "$PROJECT_DIR/mobile"
        TEST_OUTPUT=$(flutter test 2>&1 | tr '\r' '\n') || true
        if echo "$TEST_OUTPUT" | grep -qiE "failed|error|exception"; then
            FAILURES="${FAILURES}Mobile tests failed:\n${TEST_OUTPUT}\n\n"
        fi
    fi
fi

# If any failures, block completion
if [ -n "$FAILURES" ]; then
    echo -e "Quality gate BLOCKED task completion for '${TASK_SUBJECT}' (${TEAMMATE_NAME}).\n\nTest failures detected:\n${FAILURES}\nFix the failing tests before marking the task as completed." >&2
    exit 2
fi

echo "Quality gate passed for '${TASK_SUBJECT}'" >&2
exit 0
