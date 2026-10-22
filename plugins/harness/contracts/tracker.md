# Tracker contract

The `harness` plugin runs the whole dev process without an issue tracker. Tracking (reading work items, moving them through statuses, logging progress, closing milestones) is an optional module that plugs in through one command: `harness-tracker`.

A tracker module is a Claude Code plugin that ships an executable `bin/harness-tracker`. Claude Code puts every enabled plugin's `bin/` directory on `PATH`, so the bare command resolves to it. This file is the whole interface; a module that implements it works with every harness skill, command, and agent. The reference implementation is `tracker-github` in this marketplace.

## Detection

The `harness` plugin ships `harness-tracker-status`, which runs `which -a harness-tracker` and prints one of:

- **none**: no tracker. Every issue, status, comment, and milestone operation is skipped; work items come from the user's request.
- **active**: exactly one tracker. Use `harness-tracker` as described below.
- **conflict**: more than one enabled plugin ships `harness-tracker`. The first on `PATH` wins silently; the warning names every copy and the winner. Enable only one tracker module per project.

Claude Code adds plugin `bin/` directories to `PATH` for the Bash tool but not for hooks, so the harness SessionStart hook cannot decide this itself: it tells the session to run `harness-tracker-status` once, with the Bash tool, before the first tracker operation. Sub-agents do the same (or `command -v harness-tracker`) since they don't see the hook's output.

## Concepts

- **Work item**: one unit of work, identified by a **ref**: an opaque token with no whitespace (for GitHub, an issue number; a leading `#` is accepted). Core never parses refs; it only passes them back.
- **Epic**: a work item that groups others. It is not itself a work item; `resolve` expands it into its children.
- **Milestone**: a named batch of work items that ships as one release. Core uses the milestone name for the integration branch (`integration/<milestone>`) and the release version.
- **Labels**: free-form tags. Core gives meaning to two: `test` (route to `harness:test-agent`) and `epic` (expanded by `resolve`). A module maps its own concepts onto these names.

### Status vocabulary

Statuses are neutral, lowercase, hyphenated. The module maps them to its tracker's own values.

| Status | Meaning | Written by core |
| --- | --- | --- |
| `backlog` | Not ready to work | no |
| `ready` | Scoped and ready to pick up | no |
| `in-progress` | An agent is working on it | yes |
| `staged` | Implemented on a branch, not yet released | yes |
| `complete` | Shipped in a release | yes |
| `abandoned` | Won't be done | no |

A module must accept the three statuses core writes. The others are optional.

### Size vocabulary

`small`, `medium`, `large`, or `-` when unset. Core uses size to pick the agent tier in `/harness:workstream`.

## Conventions

- **Output**: list-like output is tab-separated with one header line; columns are fixed as documented below. Missing values print as `-`. Human-readable text (from `read`) is free-form.
- **Diagnostics** go to stderr, never stdout.
- **Refs**: subcommands that take several refs accept them as separate arguments.

### Exit codes

| Code | Meaning | What core does |
| --- | --- | --- |
| `0` | Success | Continue |
| `1` | The operation failed (tracker unreachable, item not found, not configured) | For `resolve` and `read`: stop and report to the user, since there is nothing to work from. For writes (`set-status`, `comment`, `create`, `close-milestone`): report the failure in the summary and carry on with the code work |
| `2` | Usage error (bad arguments) | Fix the call; if unsure, run `harness-tracker help` |
| `3` | Subcommand not supported by this module | Skip that operation as in no-tracker mode, and say so in the summary |

## Subcommands

### `help`

Prints usage. Exit 0. Also accepts `--help` and `-h`.

### `resolve <milestone>` / `resolve --items <ref>...`

Turns a milestone, or a list of refs, into the flat list of open, actionable work items: epics are replaced by their open children, closed items are dropped, duplicates are removed.

```
ID	TITLE	LABELS	PARENT
42	Add CSV export	feature	12
57	Login redirect loops	bug	-
```

`LABELS` is comma-separated. `PARENT` is the epic's ref, or `-`.

### `read <ref>...`

Prints the full text of each item: at least title, state, labels, milestone, and body (description, acceptance criteria, constraints). Free-form.

### `fields <ref>...`

```
ID	STATUS	SIZE	LABELS
42	ready	small	feature
```

`STATUS` uses the status vocabulary, `SIZE` the size vocabulary; either is `-` if unset or unknown.

### `set-status <ref>... <status>`

Moves every listed item to `<status>` (the last argument). Prints one confirmation line per item.

### `comment <ref>`

Adds a comment to the item. The comment body (Markdown) is read from stdin.

### `create --title <title> [--body-file <file|->] [--label <label>] [--milestone <milestone>] [--status <status>] [--size <size>]`

Creates a work item. The first line of stdout is the new item's ref; anything after it (a URL, confirmations) is informational.

### `close-milestone <milestone> [--dry-run]`

Release bookkeeping, run by `harness:merge-handler` after a release is tagged: closes the milestone's open items, moves all of its items to `complete`, and closes the milestone itself. `--dry-run` prints what would change and changes nothing; core always runs it first and shows the user.

## Extras

A module may add subcommands of its own (for example `list` or `set-size`). Core never calls them; the module's own skills may.
