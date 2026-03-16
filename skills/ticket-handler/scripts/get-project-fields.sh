#!/usr/bin/env bash
set -euo pipefail

# Get GitHub Project fields (Status, Size) for one or more issues.
# Usage:
#   get-project-fields.sh <project-id> <issue-numbers>
#   get-project-fields.sh PVT_abc123 1
#   get-project-fields.sh PVT_abc123 1,2,5
#   get-project-fields.sh PVT_abc123 1-10

if [[ $# -lt 2 ]]; then
    echo "Usage: get-project-fields.sh <project-id> <issue-numbers>" >&2
    exit 1
fi

PROJECT_ID="$1"
shift

# Expand comma-separated values and ranges
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

echo -e "NUM\tSTATUS\tSIZE"

for num in "${issues[@]}"; do
    # Get the project item ID for this issue
    result=$(gh api graphql -f query='
    query($projectId: ID!) {
      node(id: $projectId) {
        ... on ProjectV2 {
          items(first: 100) {
            nodes {
              id
              content {
                ... on Issue {
                  number
                }
              }
              fieldValues(first: 20) {
                nodes {
                  ... on ProjectV2ItemFieldSingleSelectValue {
                    name
                    field {
                      ... on ProjectV2SingleSelectField {
                        name
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }' -f projectId="$PROJECT_ID" --jq "
        .data.node.items.nodes[] |
        select(.content.number == $num) |
        {
            status: ([.fieldValues.nodes[] | select(.field.name == \"Status\") | .name] | first // \"none\"),
            size: ([.fieldValues.nodes[] | select(.field.name == \"Size\") | .name] | first // \"none\")
        } |
        \"$num\t\(.status)\t\(.size)\"
    " 2>/dev/null)

    if [[ -n "$result" ]]; then
        echo "$result"
    else
        echo -e "$num\t(not in project)\t-"
    fi
done
