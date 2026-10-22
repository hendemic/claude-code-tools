#!/usr/bin/env bash
set -euo pipefail

# Read the full text of one or more GitHub issues by number.
# Usage:
#   read-issues.sh 1
#   read-issues.sh 1 2 5
#   read-issues.sh 1-10

if [[ $# -eq 0 ]]; then
    echo "Usage: read-issues.sh <issue-number> [issue-number...] or <start-end>" >&2
    exit 1
fi

# Expand comma-separated values and ranges (e.g., "1,2,5" or "1-5" or "1,3-5,8")
issues=()
for arg in "$@"; do
    IFS=',' read -ra parts <<< "$arg"
    for part in "${parts[@]}"; do
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            start="${BASH_REMATCH[1]}"
            end="${BASH_REMATCH[2]}"
            for ((i=start; i<=end; i++)); do
                issues+=("$i")
            done
        else
            issues+=("$part")
        fi
    done
done

for num in "${issues[@]}"; do
    echo "════════════════════════════════════════════════════════════"
    echo "ISSUE #$num"
    echo "════════════════════════════════════════════════════════════"
    gh issue view "$num" --json number,title,state,body,labels,milestone,assignees --jq '
        "Title:     \(.title)\nState:     \(.state)\nLabels:    \(.labels | map(.name) | join(", "))\nMilestone: \(.milestone.title // "none")\nAssignees: \(.assignees | map(.login) | join(", "))\n\n\(.body // "(no description)")"
    '
    echo ""
done
