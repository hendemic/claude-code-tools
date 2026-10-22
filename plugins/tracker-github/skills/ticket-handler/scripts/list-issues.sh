#!/usr/bin/env bash
set -euo pipefail

# List GitHub issues with optional filtering.
# Usage:
#   list-issues.sh                    # all open issues
#   list-issues.sh --all              # all issues (open + closed)
#   list-issues.sh --milestone "0.0.2" # issues in a milestone (pattern match)
#   list-issues.sh --milestone 3      # issues in a milestone (by ID)
#   list-issues.sh --label feature    # issues with a specific label

STATE="open"
MILESTONE=""
LABEL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            STATE="all"
            shift
            ;;
        --milestone)
            MILESTONE="$2"
            shift 2
            ;;
        --label)
            LABEL="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

args=(--state "$STATE" --json number,title,state,labels,milestone --jq '
    .[] | "\(.number)\t\(.state)\t\(.title)\t\(.labels | map(.name) | join(","))\t\(.milestone.title // "")"
')

if [[ -n "$LABEL" ]]; then
    args+=(--label "$LABEL")
fi

# If milestone is provided, resolve it (pattern match on title or use as-is for ID)
if [[ -n "$MILESTONE" ]]; then
    if [[ "$MILESTONE" =~ ^[0-9]+$ ]]; then
        # Numeric — could be an ID, try to resolve the title
        resolved=$(gh api repos/:owner/:repo/milestones/"$MILESTONE" --jq '.title' 2>/dev/null || echo "")
        if [[ -n "$resolved" ]]; then
            args+=(--milestone "$resolved")
        else
            echo "Milestone ID $MILESTONE not found" >&2
            exit 1
        fi
    else
        # Pattern match: find milestones whose title contains the query
        match=$(gh api repos/:owner/:repo/milestones --jq \
            "[.[] | select(.title | test(\"$MILESTONE\"; \"i\"))] | .[0].title // empty" 2>/dev/null)
        if [[ -n "$match" ]]; then
            args+=(--milestone "$match")
        else
            echo "No milestone matching '$MILESTONE'" >&2
            exit 1
        fi
    fi
fi

echo -e "NUM\tSTATE\tTITLE\tLABELS\tMILESTONE"
gh issue list "${args[@]}"
