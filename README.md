# claude-code-tools

Plugin marketplace `hendemic-harness`:

- `harness` (required): the dev process. `/harness:workstream`, `/harness:issue`, merge-handler, dev/test agents.
- `tracker-github` (optional): issue tracking on GitHub Issues + a GitHub Project.
- `harness-rust` (optional): Rust conventions.

## Set up a project

Run from the project root.

1. Add the marketplace:

   ```sh
   claude plugin marketplace add hendemic/claude-code-tools --scope project
   ```

2. Edit `.claude/settings.json` so it has these keys (keep anything else already there). Drop the optional plugins you don't want:

   ```json
   {
     "extraKnownMarketplaces": {
       "hendemic-harness": {
         "source": { "source": "github", "repo": "hendemic/claude-code-tools", "ref": "v0.0.1" }
       }
     },
     "enabledPlugins": {
       "harness@hendemic-harness": true,
       "tracker-github@hendemic-harness": true,
       "harness-rust@hendemic-harness": true
     }
   }
   ```

3. Add any `## Harness: …` sections that apply to the project's `CLAUDE.md` (see [Project contract](#project-contract)).
4. If using `tracker-github`, check the [tracker requirements](#tracker-github).
5. Commit `.claude/settings.json` and `CLAUDE.md`.
6. Start a new `claude` session and trust the folder. Check that:
   - `/plugin` lists the `@hendemic-harness` plugins;
   - `harness-tracker-status` prints `active` with a tracker, `none` without one. `CONFLICT` means more than one tracker is enabled.

## Project contract

Optional sections in the project's `CLAUDE.md`. Leave out any that don't apply.

| Section | Contents |
| --- | --- |
| `## Harness: escalation signals` | Paths or kinds of work that always go to the large dev agent |
| `## Harness: quality gates` | Typecheck, format, lint and test commands, and any prerequisites |
| `## Harness: testing layout` | Where tests live, helpers, frameworks |
| `## Harness: user-only checks` | Checks agents must not run; you run them before a release |
| `## Harness: lockfile` | Lockfile name and reinstall command |
| `## Harness: conflict hotspots` | Files that often conflict when parallel work merges |

## tracker-github

Requires:

- `gh` with the `project` scope (`gh auth refresh -h github.com -s project`) and `jq`.
- The repo linked to one open GitHub Project with single-select fields `Status` and `Size` (Small, Medium, Large).
- Epics labelled `epic`, with their work as GitHub sub-issues; test work labelled `test`.

Status names are matched to the board's options automatically, and epics follow their sub-issues. When the defaults don't fit, set these in the `env` block of `.claude/settings.json`:

| Variable | Set when |
| --- | --- |
| `TRACKER_GITHUB_PROJECT_ID` | The repo has several linked projects, or none |
| `TRACKER_GITHUB_STATUS_FIELD_ID` / `TRACKER_GITHUB_SIZE_FIELD_ID` | The fields aren't named `Status` / `Size` |
| `TRACKER_GITHUB_STATUS_MAP` | A status isn't recognised, e.g. `complete=Shipped,abandoned=Dropped` |

`harness-tracker project` shows what it's using.

## Update a project

Change `ref` in `.claude/settings.json` to the new tag, run `claude plugin marketplace update hendemic-harness`, and start a new session.

## Machine setup (once)

Link the personal rules in `user-rules/` into `~/.claude/rules/`:

```sh
git clone git@github.com:hendemic/claude-code-tools.git && ./claude-code-tools/install-user-rules.sh
```

## Release the harness

1. Bump `version` in each changed `plugins/*/.claude-plugin/plugin.json`. Installs only update when the version changes.
2. `claude plugin validate .` and each plugin directory.
3. Merge `dev` → `main`, then tag and push only that tag: `git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z`.

Test local changes with `claude --plugin-dir ./plugins/harness` (repeat the flag for other plugins).
