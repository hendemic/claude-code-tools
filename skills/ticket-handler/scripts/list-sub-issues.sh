#!/usr/bin/env bash
set -euo pipefail

# List sub-issues of a GitHub issue (epic).
# Usage:
#   list-sub-issues.sh 58
#   list-sub-issues.sh 58 59 60
#   list-sub-issues.sh 58-60

if [[ $# -eq 0 ]]; then
    echo "Usage: list-sub-issues.sh <issue-number> [issue-number...]" >&2
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

for num in "${issues[@]}"; do
    result=$(gh api graphql -f query="
        query {
            repository(owner:\"$(gh repo view --json owner -q .owner.login)\", name:\"$(gh repo view --json name -q .name)\") {
                issue(number: $num) {
                    number
                    title
                    labels(first: 10) { nodes { name } }
                    subIssues(first: 50) {
                        nodes {
                            number
                            title
                            state
                            labels(first: 10) { nodes { name } }
                        }
                    }
                }
            }
        }
    ")

    parent_title=$(echo "$result" | jq -r '.data.repository.issue.title')
    is_epic=$(echo "$result" | jq -r '.data.repository.issue.labels.nodes | map(.name) | any(. == "epic")')
    sub_count=$(echo "$result" | jq '.data.repository.issue.subIssues.nodes | length')

    echo "════════════════════════════════════════════════════════════"
    echo "ISSUE #$num: $parent_title (epic: $is_epic, sub-issues: $sub_count)"
    echo "════════════════════════════════════════════════════════════"

    if [[ "$sub_count" -gt 0 ]]; then
        echo -e "NUM\tSTATE\tTITLE\tLABELS"
        echo "$result" | jq -r '.data.repository.issue.subIssues.nodes[] | "\(.number)\t\(.state)\t\(.title)\t\(.labels.nodes | map(.name) | join(","))"'
    else
        echo "(no sub-issues)"
    fi
    echo ""
done
