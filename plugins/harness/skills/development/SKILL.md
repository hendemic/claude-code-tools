---
name: development
description: Development workflow for implementing work items, with or without an issue tracker. Handles reading the work, branching, implementation, logging, and status updates. Reference this when working on items directly (not via sub-agents).
---

# Tracker mode
Issue tracking is optional. Find out which mode you're in before the first tracker operation:

- Run `harness-tracker-status` once with the Bash tool (the SessionStart hook asks for this; sub-agents don't see the hook, so check yourself).
- **Tracker active**: work items are refs in the tracker. Use `harness-tracker` as described below, per the harness tracker contract (`contracts/tracker.md` in the harness plugin). If a subcommand exits `3` (unsupported), skip that step as in no-tracker mode and say so in your summary. If a write (`set-status`, `comment`, `create`) fails with exit `1`, report it in your summary and carry on with the code.
- **No tracker**: work items are the text you were given (in the prompt, the user's request, or a plan file). Skip every status update, issue comment, and issue creation step below. Everything else is the same.

# Setup
When given work items:
1. Understand the full scope.
   - Tracker: `harness-tracker read <ref>...`, then `harness-tracker fields <ref>...` to check current status.
   - No tracker: read the work item text you were given. If it doesn't state acceptance criteria, write down the ones you're working to before you start.
2. Tracker: move the items to `in-progress` with `harness-tracker set-status <ref>... in-progress`.

# Branching
- **Base**: inside a worktree created by `/harness:workstream`, branch from the worktree's current HEAD (a detached HEAD on `integration/<milestone>` or `origin/dev`) — don't check out `dev` first. Otherwise, branch from an up-to-date `dev`.
- **Multiple related items (epic)**: Create an `epic/*` branch from the base, then create `feature/*` branches from the epic branch for each item. Merge each feature branch back into the epic branch as it's completed.
- **Single item**: Create a `feature/*` branch directly from the base
- Branch names reflect the work: with a tracker, lead with the ref (e.g., `feature/42-add-imap-scanning`, `epic/12-auth-overhaul`); without one, use a short slug (e.g., `feature/add-imap-scanning`)
- Use the **harness:git-flow** skill for branching conventions

# Implementation
- Assess dependencies and the proper order to implement
- Work through each item's acceptance criteria
- Make atomic commits as progress is made
- Follow all project rules, including any language conventions in `.claude/rules/`

# Logging
When completing work on an item, write a summary of:
- Changes made
- Key decisions and rationale
- Any concerns or follow-ups

Tracker: post it on the item with `harness-tracker comment <ref>` (body on stdin). No tracker: put it in your final report to the user or orchestrator.

# Completion
1. Commit all remaining changes to the feature branch and leave it unmerged (feature branches still merge into their own epic branch, as above).
2. Tracker: `harness-tracker set-status <ref>... staged`. Don't set the epic's status; the tracker rolls it up from its sub-issues.

# Constraints
- <important> Implementing work never includes merging into `dev`, `integration/*` or `main`. If you are a sub-agent, never merge into them. Landing the branch is a separate step through harness:merge-handler: the workstream orchestrator merges sub-agent branches into `integration/<milestone>`, and the user asks for anything else. </important>
- Do not open PRs
- Do not close issues — that happens at release time
