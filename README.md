# claude-code-tools

A personal Claude Code dev-process harness, packaged as a plugin marketplace named `hendemic-harness`.

| Plugin | What it provides |
| --- | --- |
| `harness` | Skills `development`, `git-flow`, `merge-handler`; commands `/harness:issue`, `/harness:workstream`; agents `harness:dev-agent-sm`, `harness:dev-agent-lg`, `harness:test-agent`; the `harness-tracker-status` command; a SessionStart hook that loads the version-control rules and points the session at the tracker check |
| `tracker-github` | Optional issue-tracking module for GitHub Issues + a GitHub Project: the `harness-tracker` command and the `tracker-github:ticket-handler` skill |
| `harness-rust` | Skill `rust-conventions` for writing, testing, and reviewing Rust |

Everything is namespaced by plugin, e.g. `/harness:workstream 0.6.9` or `tracker-github:ticket-handler`.

## Modules: issue tracking is optional

`harness` runs the whole dev process on its own: worktree isolation, sub-agents, per-workstream integration branches, merge-handler, and the release flow. Issue tracking plugs in as a module.

- **No tracker** (enable only `harness`): `/harness:workstream` takes a free-text request or a plan file, splits it into work items, and presents the plan for approval. You agree a slug that names the integration branch (`integration/<slug>`). Sub-agents get each work item's text in their prompt and report their summaries back instead of commenting on issues. Status updates, issue comments, and milestone closing are skipped; at release time merge-handler asks you for the version.
- **With a tracker** (also enable a tracker module, e.g. `tracker-github@hendemic-harness`): `/harness:workstream 0.6.9` resolves a milestone (or a list of issue refs) into work items, sizes drive the agent tier, statuses move `in-progress → staged → complete`, agents log to the issues, and the release closes the milestone.

A tracker module is a plugin that ships a `bin/harness-tracker` command implementing [the tracker contract](plugins/harness/contracts/tracker.md). Claude Code puts every enabled plugin's `bin/` on `PATH`, so core skills just call `harness-tracker`. Run `harness-tracker-status` to see which mode a session is in; it warns if more than one enabled plugin ships `harness-tracker` (only the first on `PATH` would run). Enable at most one tracker module per project.

### tracker-github setup

- `gh` authenticated with the `project` scope (`gh auth refresh -s project`), and `jq` installed.
- The repository linked to exactly one open GitHub Project with single-select fields `Status` (`Backlog`, `Ready`, `In Progress`, `Staged`, `Complete`, `Abandoned`) and `Size` (`Small`, `Medium`, `Large`). Epics are issues labelled `epic` with GitHub sub-issues; test work is labelled `test`.
- If several projects are linked, or the fields are named differently, set `TRACKER_GITHUB_PROJECT_ID` (and optionally `TRACKER_GITHUB_STATUS_FIELD_ID`, `TRACKER_GITHUB_SIZE_FIELD_ID`) in the `env` block of `.claude/settings.json`. `harness-tracker project` shows what it found.

## Add to a project

From the project root:

```sh
claude plugin marketplace add hendemic/claude-code-tools --scope project
```

Then enable the plugins in `.claude/settings.json`. The finished file looks like this (pinned to a release):

```json
{
  "extraKnownMarketplaces": {
    "hendemic-harness": {
      "source": {
        "source": "github",
        "repo": "hendemic/claude-code-tools",
        "ref": "v0.2.0"
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

Leave out `tracker-github@hendemic-harness` to run without an issue tracker.

Commit `.claude/settings.json`. Once a collaborator trusts the folder, Claude Code fetches the marketplace and loads the plugins; no separate install step is needed.

**Pinned vs floating.** With `"ref": "vX.Y.Z"` the project stays on that release. Leave `ref` out to follow the default branch, picking up whatever version the plugin manifests declare on it.

## Project contract

The harness is project-agnostic. Anything project-specific lives in the project's own `CLAUDE.md`, under optional `## Harness: <name>` sections that the skills, commands, and agents read:

| Section | Contents | Used by | If absent |
| --- | --- | --- | --- |
| `## Harness: escalation signals` | Paths, keywords, or kinds of work that always go to `harness:dev-agent-lg`, regardless of Size | `/harness:workstream` | No escalation; agents are picked by Size (or, without a tracker, the orchestrator's judgment) and labels only |
| `## Harness: quality gates` | Typecheck, format, lint, and test commands; which are required; prerequisites (services that must be running) | `harness:test-agent`, `harness:merge-handler` | test-agent uses the project's standard commands and says which it ran; merge-handler asks the user before the milestone-close gate |
| `## Harness: testing layout` | Where tests live per layer, shared helpers, frameworks, unit vs integration per layer | `harness:test-agent` | Infer from existing tests; ask before inventing a layout |
| `## Harness: user-only checks` | Checks agents must not run; the user runs them before a release | `harness:test-agent`, `harness:merge-handler` | No release reminder; nothing is off limits beyond the usual rules |
| `## Harness: lockfile` | Lockfile name and the reinstall command | `harness:merge-handler` | Recognise the package manager's lockfile from the repo |
| `## Harness: conflict hotspots` | Files that commonly conflict when parallel work merges | `harness:git-flow`, `harness:merge-handler`, `/harness:workstream` | Review conflicts case by case |

A minimal example:

```markdown
## Harness: escalation signals
- Anything under `db/migrations/` or mentioning a schema change
- Changes to `src/auth/`

## Harness: quality gates
- Required: `make typecheck`, `make fmt-check`, `make lint`
- Full suite: `make test` (integration tier needs the local database running: `make db-up`)

## Harness: testing layout
- Unit tests next to the code in `src/**/*_test.*`; integration tests in `tests/integration/`
- Shared fixtures in `tests/helpers/`; integration tests use a real database, never a mock

## Harness: user-only checks
- End-to-end browser suite: `make e2e`

## Harness: lockfile
- `package-lock.json`; reinstall with `npm install`

## Harness: conflict hotspots
- `src/strings.json`, sequentially numbered files in `db/migrations/`
```

## Upgrade a pinned project

1. Bump `ref` in `.claude/settings.json` to the new tag.
2. `claude plugin marketplace update hendemic-harness`
3. Start a new session (or `/reload-plugins`).

## Local development

Load a plugin straight from a checkout for one session, without installing it:

```sh
claude --plugin-dir ./plugins/harness --plugin-dir ./plugins/tracker-github --plugin-dir ./plugins/harness-rust
```

Check manifests and components before committing:

```sh
claude plugin validate .
claude plugin validate ./plugins/harness
claude plugin validate ./plugins/tracker-github
claude plugin validate ./plugins/harness-rust
```

## Release checklist

1. Bump `version` in `.claude-plugin/plugin.json` of every plugin that changed. The plugin cache is keyed by version, so a change shipped without a bump is never picked up by existing installs.
2. Run `claude plugin validate` on the marketplace root and each plugin.
3. Merge to `main`, then tag: `git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z`.
4. Bump `ref` in consuming projects.

## User rules

`user-rules/` holds rules that apply to every project rather than to the harness (bash usage, auto-memory, no /schedule pitches). Link them into `~/.claude/rules/`:

```sh
./install-user-rules.sh
```

It is safe to re-run, and it skips any existing file that isn't a symlink.
