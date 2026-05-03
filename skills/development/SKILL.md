---
name: development
description: Development workflow for implementing GitHub issues. Handles reading tickets, branching, implementation, logging, and status updates. Reference this when working on issues directly (not via sub-agents).
---

# Setup
When given an issue to work on:
1. Read the issue using **ticket-handler** scripts to understand the full scope
2. Use `get-project-fields.sh` to check current status
3. Update status to `In Progress` using `set-status.sh`

# Branching
- **Multiple issues (epic)**: Create an `epic/*` branch from `dev`, then create `feature/*` branches from the epic branch for each issue. Merge each feature branch back into the epic branch as it's completed.
- **Single issue**: Create a `feature/*` branch directly from `dev`
- Branch names should reflect the issue (e.g., `feature/42-add-imap-scanning`, `epic/12-auth-overhaul`)
- Use the **git-flow** skill for branching conventions

# Implementation
- Assess dependencies and the proper order to implement
- Work through each issue's acceptance criteria
- Make atomic commits as progress is made
- Follow all project rules

# Logging
When completing work on an issue, add a comment to the GitHub issue summarizing:
- Changes made
- Key decisions and rationale
- Any concerns or follow-ups

# Completion
1. Commit all remaining changes to the feature branch. DO NOT merge to `dev` or `main`.
2. Update issue status to `Staged` using `set-status.sh`. Update the epic status to `Staged` as well, if its completed.

# Constraints
- <important> Do not merge into `dev` or `main` </important>
- Do not open PRs
- Do not close issues — that happens at merge time
