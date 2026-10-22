#!/usr/bin/env bash
set -euo pipefail

# Close all open issues in a milestone and mark them as completed.
# Usage:
#   close-milestone.sh "0.0.2"        # pattern match on milestone title
#   close-milestone.sh --id 3         # by milestone ID
#   close-milestone.sh "0.0.2" --dry-run  # preview without closing
#   close-milestone.sh "0.0.2" --skip 12,14   # leave these issues open

DRY_RUN=false
MILESTONE=""
BY_ID=false
SKIP=","

while [[ $# -gt 0 ]]; do
    case "$1" in
        --id)
            BY_ID=true
            MILESTONE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip)
            SKIP=",$2,"
            shift 2
            ;;
        *)
            MILESTONE="$1"
            shift
            ;;
    esac
done

if [[ -z "$MILESTONE" ]]; then
    echo "Usage: close-milestone.sh <milestone-pattern> | --id <milestone-id> [--dry-run]" >&2
    exit 1
fi

# Resolve milestone title
if [[ "$BY_ID" == true ]]; then
    title=$(gh api repos/:owner/:repo/milestones/"$MILESTONE" --jq '.title' 2>/dev/null || echo "")
    if [[ -z "$title" ]]; then
        echo "Milestone ID $MILESTONE not found" >&2
        exit 1
    fi
else
    title=$(gh api repos/:owner/:repo/milestones --jq \
        "[.[] | select(.title | test(\"$MILESTONE\"; \"i\"))] | .[0].title // empty" 2>/dev/null)
    if [[ -z "$title" ]]; then
        echo "No milestone matching '$MILESTONE'" >&2
        exit 1
    fi
fi

echo "Milestone: $title"

# Get all open issues in this milestone
issue_numbers=$(gh issue list --milestone "$title" --state open --json number --jq '.[].number')

if [[ -z "$issue_numbers" ]]; then
    echo "No open issues in milestone '$title'"
    exit 0
fi

count=$(echo "$issue_numbers" | wc -l)
echo "Found $count open issue(s)"

for num in $issue_numbers; do
    if [[ "$SKIP" == *",$num,"* ]]; then
        echo "  Skipping #$num (left open)"
        count=$((count - 1))
        continue
    fi
    if [[ "$DRY_RUN" == true ]]; then
        echo "  [dry-run] Would close #$num"
    else
        gh issue close "$num" --reason completed
        echo "  Closed #$num"
    fi
done

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run complete. No issues were closed."
else
    echo "Done. Closed $count issue(s)."
fi
