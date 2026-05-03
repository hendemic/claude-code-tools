---
name: ticket-handler
description: Create, list, and manage GitHub issues. Use when the user asks to create an issue, check issues, or
pull issue details.
---

# Reading issues
To pull issues or tickets to work on, you have a series of scripts available to help:

| Script | Purpose | Usage |
|--------|---------|-------|
| `~/.claude/skills/ticket-handler/scripts/list-issues.sh` | List issues with filtering | `--all`, `--milestone "0.0.2"`, `--milestone 3`, `--label feature` |
| `~/.claude/skills/ticket-handler/scripts/read-issues.sh` | Read full issue text | `<number> [number...]`, `1,2,5`, or `1-10` |
| `~/.claude/skills/ticket-handler/scripts/get-project-fields.sh` | Get Status and Size from GitHub Project | `<project-id> <numbers>` (e.g., `PVT_abc 1,2,5`) |
| `~/.claude/skills/ticket-handler/scripts/set-status.sh` | Update issue Status in GitHub Project | `<project-id> <status-field-id> <numbers> <status>` (e.g., `PVT_abc PVTSSF_xyz 1,2,5 "In Progress"`) |
| `~/.claude/skills/ticket-handler/scripts/set-size.sh` | Update issue Size in GitHub Project | `<project-id> <size-field-id> <numbers> <size>` (e.g., `PVT_abc PVTSSF_xyz 1,2,5 "Small"`) |
| `~/.claude/skills/ticket-handler/scripts/list-sub-issues.sh` | List sub-issues of an epic | `<number> [number...]`, `58,59,60`, or `58-60` |
| `~/.claude/skills/ticket-handler/scripts/create-issue.sh` | Create issue, add to project, set status and size | `<project-id> <status-field-id> <size-field-id> --title "..." [--body "..." --label feature --milestone "..." --status "Ready" --size "Small"]` |
| `~/.claude/skills/ticket-handler/scripts/close-milestone.sh` | Close all open issues in a milestone | `"0.0.2"` or `--id 3`, supports `--dry-run` |

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
