#!/usr/bin/env bash
set -euo pipefail

# Get GitHub Project fields (Status, Size) for one or more issues.
# Paginates through every item in the project (100 per page) so issues at
# any position are found.
#
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

# Paginate through all project items once and build a num → "status\tsize" map.
declare -A item_map
cursor=""
while :; do
    if [[ -z "$cursor" ]]; then
        page=$(gh api graphql -f query='
        query($projectId: ID!) {
          node(id: $projectId) {
            ... on ProjectV2 {
              items(first: 100) {
                pageInfo { hasNextPage endCursor }
                nodes {
                  content { ... on Issue { number } }
                  fieldValues(first: 20) {
                    nodes {
                      ... on ProjectV2ItemFieldSingleSelectValue {
                        name
                        field { ... on ProjectV2SingleSelectField { name } }
                      }
                    }
                  }
                }
              }
            }
          }
        }' -f projectId="$PROJECT_ID")
    else
        page=$(gh api graphql -f query='
        query($projectId: ID!, $cursor: String!) {
          node(id: $projectId) {
            ... on ProjectV2 {
              items(first: 100, after: $cursor) {
                pageInfo { hasNextPage endCursor }
                nodes {
                  content { ... on Issue { number } }
                  fieldValues(first: 20) {
                    nodes {
                      ... on ProjectV2ItemFieldSingleSelectValue {
                        name
                        field { ... on ProjectV2SingleSelectField { name } }
                      }
                    }
                  }
                }
              }
            }
          }
        }' -f projectId="$PROJECT_ID" -f cursor="$cursor")
    fi

    while IFS=$'\t' read -r num status size; do
        [[ -z "$num" || "$num" == "null" ]] && continue
        item_map[$num]=$'\t'"${status}"$'\t'"${size}"
    done < <(echo "$page" | jq -r '
        .data.node.items.nodes[] |
        select(.content.number != null) |
        [
            .content.number,
            ([.fieldValues.nodes[] | select(.field.name == "Status") | .name] | first // "none"),
            ([.fieldValues.nodes[] | select(.field.name == "Size") | .name] | first // "none")
        ] | @tsv
    ')

    has_next=$(echo "$page" | jq -r '.data.node.items.pageInfo.hasNextPage')
    cursor=$(echo "$page" | jq -r '.data.node.items.pageInfo.endCursor')
    [[ "$has_next" == "true" ]] || break
done

echo -e "NUM\tSTATUS\tSIZE"
for num in "${issues[@]}"; do
    if [[ -n "${item_map[$num]:-}" ]]; then
        echo -e "${num}${item_map[$num]}"
    else
        echo -e "${num}\t(not in project)\t-"
    fi
done
