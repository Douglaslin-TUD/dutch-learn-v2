#!/bin/bash
# TeammateIdle Hook - Prevents premature idle
# Checks if the teammate still has in-progress tasks.
# Exit code 0 = allow idle
# Exit code 2 = block idle and send feedback to keep working

set -euo pipefail

INPUT=$(cat)
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // "unknown"')
TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // "unknown"')

TASKS_DIR="$HOME/.claude/tasks/${TEAM_NAME}"

# If no task directory exists, allow idle
if [ ! -d "$TASKS_DIR" ]; then
    exit 0
fi

# Check for in-progress tasks owned by this teammate
IN_PROGRESS=0
for task_file in "$TASKS_DIR"/*.json; do
    [ -f "$task_file" ] || continue

    TASK_STATUS=$(jq -r '.status // "unknown"' "$task_file" 2>/dev/null)
    TASK_OWNER=$(jq -r '.owner // ""' "$task_file" 2>/dev/null)

    if [ "$TASK_STATUS" = "in_progress" ] && [ "$TASK_OWNER" = "$TEAMMATE_NAME" ]; then
        TASK_SUBJECT=$(jq -r '.subject // "unknown"' "$task_file" 2>/dev/null)
        IN_PROGRESS=$((IN_PROGRESS + 1))
        echo "You still have an in-progress task: '${TASK_SUBJECT}'. Complete it or mark it as completed before going idle." >&2
        exit 2
    fi
done

# Check for pending unblocked tasks with no owner
for task_file in "$TASKS_DIR"/*.json; do
    [ -f "$task_file" ] || continue

    TASK_STATUS=$(jq -r '.status // "unknown"' "$task_file" 2>/dev/null)
    TASK_OWNER=$(jq -r '.owner // ""' "$task_file" 2>/dev/null)
    BLOCKED_BY=$(jq -r '.blockedBy // [] | length' "$task_file" 2>/dev/null)

    if [ "$TASK_STATUS" = "pending" ] && [ -z "$TASK_OWNER" ] && [ "$BLOCKED_BY" = "0" ]; then
        TASK_SUBJECT=$(jq -r '.subject // "unknown"' "$task_file" 2>/dev/null)
        echo "There are unclaimed pending tasks available (e.g., '${TASK_SUBJECT}'). Check TaskList and claim one before going idle." >&2
        exit 2
    fi
done

# No in-progress tasks and no unclaimed tasks, allow idle
exit 0
