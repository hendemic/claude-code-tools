---
name: merge-handler
description: Handles merging branches into dev and creating PRs to main. Use when the user asks to merge a branch, open a PR, or complete a milestone.
---

# Merging to dev
When asked to merge a branch into `dev`:
1. Switch to `dev` and pull latest
2. Merge the source branch into `dev`
3. Resolve any conflicts locally
4. Push `dev` to remote
5. Delete the source branch (local and remote)

# Creating PRs to main
When asked to open a PR to `main`:
1. Fetch latest from `main`
2. Resolve any conflicts between `dev` and `main` locally
3. Open the PR from `dev` to `main`
4. Wait for the user to confirm the PR is approved before proceeding

# After PR approval
Once the user confirms a PR to `main` is approved:
1. Merge the PR
2. Mark related issues as `Complete` using the harness:ticket-handler skill's `close-milestone.sh` script

# Constraints
- Only merge to `dev` or open PRs to `main` when explicitly asked
- Never force push
