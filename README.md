# claude-code-tools

A Claude Code dev-process harness, packaged as a plugin marketplace named `hendemic-harness`. It plans work into parallel workstreams, runs each in its own git worktree with dev and test sub-agents, stages the results on an integration branch, and handles merges and tagged releases. Issue tracking is an optional module.

| Plugin | What it provides |
| --- | --- |
| `harness` | The core process: skills `development`, `git-flow`, `merge-handler`; commands `/harness:workstream`, `/harness:issue`; agents `harness:dev-agent-sm`, `harness:dev-agent-lg`, `harness:test-agent`; the `harness-tracker-status` command; a SessionStart hook that loads the version-control rules |
| `tracker-github` | Optional. Issue tracking on GitHub Issues + a GitHub Project: the `harness-tracker` command and the `tracker-github:ticket-handler` skill |
| `harness-rust` | Optional. Skill `rust-conventions` for writing, testing, and reviewing Rust |

## 1. Prerequisites

- Claude Code
- git, with SSH access to GitHub
- For `tracker-github` only:
  - `gh`, authenticated with the `project` scope: `gh auth refresh -h github.com -s project`
  - `jq`

## 2. One-time machine setup

`user-rules/` holds rules that apply to every project rather than to the harness (bash usage, no auto-memory, no /schedule pitches). Link them into `~/.claude/rules/`:

```sh
git clone git@github.com:hendemic/claude-code-tools.git
cd claude-code-tools
./install-user-rules.sh
```

It symlinks each `user-rules/*.md` into `~/.claude/rules/`. Safe to re-run; it skips any existing file there that isn't a symlink.

## 3. Add the harness to a project

From the project root:

```sh
claude plugin marketplace add hendemic/claude-code-tools --scope project
```

Then make `.claude/settings.json` look like this (pinned to a release):

```json
{
  "extraKnownMarketplaces": {
    "hendemic-harness": {
      "source": {
        "source": "github",
        "repo": "hendemic/claude-code-tools",
        "ref": "v0.0.1"
      }
    }
  },
  "enabledPlugins": {
    "harness@hendemic-harness": true,
    "tracker-github@hendemic-harness": true,
    "harness-rust@hendemic-harness": true
  }
}
```

`harness` is required; drop `tracker-github` to run without an issue tracker, and `harness-rust` if the project isn't Rust.

1. Start `claude` in the project and trust the folder. Claude Code fetches the marketplace and loads the plugins; there is no separate install step.
2. Commit `.claude/settings.json` so collaborators get the same setup.
3. Confirm it loaded:
   - `/plugin` lists the enabled `@hendemic-harness` plugins.
   - Ask Claude to run `harness-tracker-status`. It prints `active` with a tracker, `none` without one, and a `CONFLICT` warning if more than one enabled plugin ships `harness-tracker` (enable at most one tracker module).

## 4. Configure the project

### Project contract (CLAUDE.md)

The harness is project-agnostic. Project-specific inputs live in the project's `CLAUDE.md` under optional `## Harness: <name>` sections:

| Section | What to put | Used by | If absent |
| --- | --- | --- | --- |
| `## Harness: escalation signals` | Paths, keywords, or kinds of work that always go to `harness:dev-agent-lg` | `/harness:workstream` | Agents are picked by Size (or the orchestrator's judgment) and labels only |
| `## Harness: quality gates` | Typecheck, format, lint, and test commands; which are required; prerequisites such as running services | `harness:test-agent`, `harness:merge-handler` | test-agent uses the project's standard commands; merge-handler asks you before the milestone-close gate |
| `## Harness: testing layout` | Where tests live per layer, shared helpers, frameworks | `harness:test-agent` | Inferred from existing tests; the agent asks before inventing a layout |
| `## Harness: user-only checks` | Checks agents must not run; you run them before a release | `harness:test-agent`, `harness:merge-handler` | No release reminder |
| `## Harness: lockfile` | Lockfile name and the reinstall command | `harness:merge-handler` | The package manager's lockfile is recognised from the repo |
| `## Harness: conflict hotspots` | Files that commonly conflict when parallel work merges | `harness:git-flow`, `harness:merge-handler`, `/harness:workstream` | Conflicts are reviewed case by case |

Example:

```markdown
## Harness: escalation signals
- Anything under `db/migrations/` or mentioning a schema change

## Harness: quality gates
- Required: `make typecheck`, `make fmt-check`, `make lint`
- Full suite: `make test` (integration tier needs the database: `make db-up`)

## Harness: testing layout
- Unit tests next to the code in `src/**/*_test.*`; integration tests in `tests/integration/`

## Harness: user-only checks
- End-to-end browser suite: `make e2e`

## Harness: lockfile
- `package-lock.json`; reinstall with `npm install`

## Harness: conflict hotspots
- `src/strings.json`, sequentially numbered files in `db/migrations/`
```

### tracker-github

Board conventions it expects:

- The repository is linked to one open GitHub Project with single-select fields `Status` and `Size`.
- `Status` options are matched case-insensitively: backlog `Backlog`/`Todo`, ready `Ready`, in-progress `In Progress`/`Doing`, staged `Staged`/`In Review`/`Review`, complete `Complete`/`Done`/`Closed`, abandoned `Abandoned`/`Won't Do`/`Wontfix`/`Closed`. `Size` options are `Small`, `Medium`, `Large`.
- Epics are issues labelled `epic` whose work items are GitHub sub-issues. Test work is labelled `test`.
- Epic status follows its sub-issues automatically: when a sub-issue moves, the epic rolls up to `in-progress`, `staged` (all sub-issues staged or complete), or `complete` (all complete). It only moves forward, and an abandoned epic is left alone. `harness-tracker set-status --no-rollup` turns this off for one call.

Settings go in the `env` block of `.claude/settings.json`, only when the defaults don't fit:

```json
{
  "env": {
    "TRACKER_GITHUB_PROJECT_ID": "PVT_...",
    "TRACKER_GITHUB_STATUS_MAP": "complete=Shipped,abandoned=Dropped"
  }
}
```

| Variable | When to set it |
| --- | --- |
| `TRACKER_GITHUB_PROJECT_ID` | Several projects are linked to the repo, or none is |
| `TRACKER_GITHUB_STATUS_FIELD_ID` | The status field isn't named `Status` |
| `TRACKER_GITHUB_SIZE_FIELD_ID` | The size field isn't named `Size` |
| `TRACKER_GITHUB_STATUS_MAP` | A board Status option isn't one of the names above (`neutral=Option`, comma separated) |

`harness-tracker project` shows the project and fields in use; `harness-tracker help` lists every subcommand.

## 5. Daily use

- **`/harness:workstream <input>`** plans and runs parallel workstreams. With a tracker, the input is a milestone (`/harness:workstream 1.4.0`) or issue numbers (`/harness:workstream 64 65`); without one, a plain request or the path to a plan file. It presents the plan for approval, then dispatches sub-agents and hands back a merge manifest. It never merges.
- **`/harness:issue <input>`** implements one or more items in the current session (issue numbers with a tracker, otherwise a description of the work).
- **Merges and releases** go through the `harness:merge-handler` skill; ask Claude to "merge `<branch>`", "land the milestone", or "open the release PR". Every step waits for you to ask.

The integration-branch flow:

- Each milestone (or, without a tracker, an agreed slug) gets `integration/<milestone>`, branched from `origin/dev`, with a worktree at `.claude/worktrees/<milestone>/integration`.
- Each workstream's agent works on its own branch in `.claude/worktrees/<milestone>/<workstream-id>` and, with a tracker, moves its items `in-progress` → `staged`.
- merge-handler merges each finished branch into the integration branch and removes its worktree.
- When the milestone is done, merge-handler runs the full quality-gate suite in the integration worktree, then merges `integration/<milestone>` into `dev`.
- A `dev` → `main` PR is a release: once you confirm it's approved, merge-handler merges it, pushes an annotated `vX.Y.Z` tag, and (with a tracker) closes the milestone, marking its items `complete`.

## 6. Updating

- **Pinned** (`"ref": "vX.Y.Z"`): the project stays on that release until you change it.
- **Floating** (no `ref`): follows the default branch.

To move a pinned project to a new release:

1. Bump `ref` in `.claude/settings.json` to the new tag.
2. `claude plugin marketplace update hendemic-harness`
3. Start a new session (or `/reload-plugins`).

## Maintaining the harness

Load plugins straight from a checkout for one session:

```sh
claude --plugin-dir ./plugins/harness --plugin-dir ./plugins/tracker-github --plugin-dir ./plugins/harness-rust
```

Validate before committing:

```sh
claude plugin validate .
claude plugin validate ./plugins/harness
claude plugin validate ./plugins/tracker-github
claude plugin validate ./plugins/harness-rust
```

Release checklist:

1. Bump `version` in `.claude-plugin/plugin.json` of every plugin that changed. The plugin cache is keyed by version, so an unbumped change never reaches existing installs.
2. Validate the marketplace root and each plugin.
3. Merge to `main`, then tag and push only that tag: `git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z`.
4. Bump `ref` in consuming projects.
