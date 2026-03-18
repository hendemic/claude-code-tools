#!/usr/bin/env bash
set -euo pipefail

# Update the Size field for an issue in the GitHub Project.
# Usage:
#   set-size.sh <project-id> <size-field-id> <issue-numbers> <size>
#   set-size.sh PVT_abc123 PVTSSF_xyz 1 "Small"
#   set-size.sh PVT_abc123 PVTSSF_xyz 1,2,5 "Medium"
#
# Valid sizes: Small, Medium, Large
# Size option IDs are queried dynamically from the project.

if [[ $# -lt 4 ]]; then
    echo "Usage: set-size.sh <project-id> <size-field-id> <issue-numbers> <size>" >&2
    exit 1
fi

PROJECT_ID="$1"
SIZE_FIELD_ID="$2"
shift 2

# Last argument is the size, everything else is issue numbers
size="${*: -1}"
set -- "${@:1:$#-1}"

# Look up the option ID for the requested size dynamically
option_id=$(gh api graphql -f query='
query($fieldId: ID!) {
  node(id: $fieldId) {
    ... on ProjectV2SingleSelectField {
      options { id name }
    }
  }
}' -f fieldId="$SIZE_FIELD_ID" --jq ".data.node.options[] | select(.name == \"$size\") | .id" 2>/dev/null)

if [[ -z "$option_id" ]]; then
    valid=$(gh api graphql -f query='
    query($fieldId: ID!) {
      node(id: $fieldId) {
        ... on ProjectV2SingleSelectField {
          options { name }
        }
      }
    }' -f fieldId="$SIZE_FIELD_ID" --jq '.data.node.options[].name' 2>/dev/null | paste -sd', ')
    echo "Invalid size: $size" >&2
    echo "Valid sizes: $valid" >&2
    exit 1
fi

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

# Get all project item IDs in one query
item_map=$(gh api graphql -f query='
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
        }
      }
    }
  }
}' -f projectId="$PROJECT_ID" --jq '
    .data.node.items.nodes[] |
    select(.content.number != null) |
    "\(.content.number)\t\(.id)"
')

for num in "${issues[@]}"; do
    item_id=$(echo "$item_map" | awk -F'\t' -v n="$num" '$1 == n { print $2 }')

    if [[ -z "$item_id" ]]; then
        echo "Issue #$num not found in project" >&2
        continue
    fi

    gh api graphql -f query='
    mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
      updateProjectV2ItemFieldValue(input: {
        projectId: $projectId
        itemId: $itemId
        fieldId: $fieldId
        value: { singleSelectOptionId: $optionId }
      }) {
        projectV2Item { id }
      }
    }' -f projectId="$PROJECT_ID" \
       -f itemId="$item_id" \
       -f fieldId="$SIZE_FIELD_ID" \
       -f optionId="$option_id" --silent

    echo "Issue #$num → $size"
done
