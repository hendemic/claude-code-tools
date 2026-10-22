---
name: ticket-handler
description: Create, list, and manage GitHub issues and their GitHub Project fields through the harness-tracker command. Use when the user asks to create an issue, check issues, or pull issue details, and for guidance on writing and sizing issues.
---

# The `harness-tracker` command
This plugin ships `harness-tracker` (on `PATH` while the plugin is enabled). It implements the harness tracker contract (`contracts/tracker.md` in the `harness` plugin) over GitHub Issues and a GitHub Project, and is the way to touch issues, statuses, and milestones. Run `harness-tracker help` for the full usage.

| Subcommand | Purpose |
|--------|---------|
| `harness-tracker resolve <milestone>` / `resolve --items 42 43` | Open work items in a milestone or issue list, epics expanded into sub-issues (TSV) |
| `harness-tracker read 42 43` | Full issue text |
| `harness-tracker fields 42 43` | Status, Size, and labels (TSV) |
| `harness-tracker set-status 42 43 <status> [--no-rollup] [--dry-run]` | Move issues on the project board; their parent epics roll up automatically |
| `harness-tracker set-size 42 <small\|medium\|large>` | Set the Size field |
| `harness-tracker comment 42 < body.md` | Comment on an issue (body from stdin) |
| `harness-tracker create --title "..." [--body-file f\|-] [--label feature] [--milestone "..."] [--status ready] [--size small]` | Create an issue, add it to the project, set Status and Size; prints the new number first |
| `harness-tracker list [--all] [--milestone M] [--label L]` | List issues |
| `harness-tracker close-milestone <milestone> [--dry-run]` | Close the milestone's open issues, mark them all Complete, close the milestone; epics with unfinished sub-issues outside the milestone are skipped |

Statuses on the command line are neutral (`backlog`, `ready`, `in-progress`, `staged`, `complete`, `abandoned`); the command maps them to the project's Status options below. Sizes are `small`, `medium`, `large`.

Epics roll up from their sub-issues: after `set-status` (and `close-milestone`), each changed issue's parent is recomputed from all its sub-issues (all complete → complete; all staged or complete → staged; any started → in-progress; abandoned sub-issues ignored), moved forward only, never touched when abandoned, and rolled up further if it has a parent itself. The command prints `rolled up #N → <status>` for each. Don't set epic statuses by hand.

## Setup
- `gh` authenticated with the `project` scope (`gh auth refresh -s project`), and `jq` installed.
- The repository is linked to exactly one open GitHub Project with single-select fields named `Status` and `Size`. If several projects are linked, or the fields are named differently, set these in the project's `.claude/settings.json` under `env`: `TRACKER_GITHUB_PROJECT_ID` (the `PVT_...` node ID), and optionally `TRACKER_GITHUB_STATUS_FIELD_ID` and `TRACKER_GITHUB_SIZE_FIELD_ID`. `harness-tracker project` shows what is in use.
- The underlying scripts live in `${CLAUDE_PLUGIN_ROOT}/skills/ticket-handler/scripts/`; call `harness-tracker` rather than the scripts.

# Writing issues
When writing issues, make sure to include:

## GitHub Issue fields
- `Title`
- `Description`
- `Label`
  - `feature`
  - `bug`
  - `refactor`
  - `test`
  - `documentation`

## GitHub Project fields
- `Status`
  - `Backlog`
  - `Ready`
  - `In Progress`
  - `Staged`
  - `Complete`
  - `Abandoned`
- `Size`
  - `Small`
  - `Medium`
  - `Large`

Tickets marked `ready` should be well-scoped, and their descriptions should include:
- Simple description of the ticket. Depending on complexity it can be 1-2 sentences, or a paragraph with bullets and numbers for complex implementations.
- Acceptance Criteria
  - [ ] listed with checkboxes
- Constraints
  - Listed with bullets

Not all tickets need to be fully scoped. For simple or placeholder tickets added to `backlog`, simply include 1-4 sentences describing the intent and scope of work.

Rules:
- Do not add technical implementation guidance to ticket description. That is the implementers job. Focus on what to change, why it matters, where key information/context lives (only when necessary), and what not to do.
