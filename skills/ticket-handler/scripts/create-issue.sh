#!/usr/bin/env bash
set -euo pipefail

# Create a GitHub issue, add it to the project, and set Status and Size.
# Usage:
#   create-issue.sh <project-id> <status-field-id> <size-field-id> [options]
#
# Required:
#   --title "Issue title"
#
# Optional:
#   --body "Description"          (default: empty)
#   --label feature               (default: none)
#   --milestone "Milestone Name"  (default: none)
#   --status "Ready"              (default: none, skipped if not set)
#   --size "Small"                (default: none, skipped if not set)
#
# Example:
#   create-issue.sh PVT_abc PVTSSF_status PVTSSF_size \
#     --title "Add feature X" \
#     --label feature \
#     --milestone "Milestone 2" \
#     --status "Ready" \
#     --size "Small" \
#     --body "Description here"

if [[ $# -lt 3 ]]; then
    echo "Usage: create-issue.sh <project-id> <status-field-id> <size-field-id> [options]" >&2
    exit 1
fi

PROJECT_ID="$1"
STATUS_FIELD_ID="$2"
SIZE_FIELD_ID="$3"
shift 3

TITLE=""
BODY=""
LABEL=""
MILESTONE=""
STATUS=""
SIZE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --title) TITLE="$2"; shift 2 ;;
        --body) BODY="$2"; shift 2 ;;
        --label) LABEL="$2"; shift 2 ;;
        --milestone) MILESTONE="$2"; shift 2 ;;
        --status) STATUS="$2"; shift 2 ;;
        --size) SIZE="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$TITLE" ]]; then
    echo "Error: --title is required" >&2
    exit 1
fi

# Build gh issue create command
gh_args=(issue create --title "$TITLE")
[[ -n "$BODY" ]] && gh_args+=(--body "$BODY")
[[ -n "$LABEL" ]] && gh_args+=(--label "$LABEL")
[[ -n "$MILESTONE" ]] && gh_args+=(--milestone "$MILESTONE")

# Create the issue and capture the URL
issue_url=$(gh "${gh_args[@]}")
echo "$issue_url"

# Extract issue number from URL
issue_num=$(echo "$issue_url" | grep -oE '[0-9]+$')

# Add to project via GraphQL (works with project node ID directly)
owner=$(gh repo view --json owner --jq .owner.login)
gh api graphql -f query='
mutation($projectId: ID!, $contentId: ID!) {
  addProjectV2ItemById(input: { projectId: $projectId, contentId: $contentId }) {
    item { id }
  }
}' -f projectId="$PROJECT_ID" \
   -f contentId="$(gh issue view "$issue_num" --json id --jq .id)" --silent

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set status if provided
if [[ -n "$STATUS" ]]; then
    "$SCRIPT_DIR/set-status.sh" "$PROJECT_ID" "$STATUS_FIELD_ID" "$issue_num" "$STATUS"
fi

# Set size if provided
if [[ -n "$SIZE" ]]; then
    "$SCRIPT_DIR/set-size.sh" "$PROJECT_ID" "$SIZE_FIELD_ID" "$issue_num" "$SIZE"
fi
