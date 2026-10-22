---
name: git-flow
description: Git branching workflow and conventions. Reference when creating branches, deciding where to branch from, batching multiple branches into a single merge into dev, staging milestone work on integration branches, and understanding the overall git process.
---

# Branch conventions

Branch types and naming are defined in the harness version-control rule (loaded at session start): `main`, `dev`, `epic/*`, `feature/*`, `refactor/*`, `test/*`, `bug/*`, `hotfix/*`, `documentation/*`, and `integration/*`. Don't redefine them here; this skill covers how they're used.

# Workflow

- `dev` is the central development branch. Work branches from `dev` (or, inside a milestone workstream, from that milestone's integration branch — see below).
- Most work items are one branch each, named after the item and work scope (e.g. `feature/42-csv-export`, `bug/57-login-redirect`; without an issue tracker, drop the ref: `feature/csv-export`).
- For epics: branch `epic/*` from the base, then branch `feature/*` off the epic. Feature branches merge back into the epic; the epic merges onward once its scope is done.
- Atomic commits as work progresses. Commit messages describe intent, not just the diff.
- Merges into `dev` or `integration/*`, release PRs to `main`, and release tags all go through the **harness:merge-handler** skill. Who may run it:
  - **Workstream orchestrator:** merges finished sub-agent branches into `integration/<milestone>`, without being asked.
  - **User:** everything else, including every merge into `dev`, on request.
  - **Sub-agents:** never. The only merge a sub-agent makes is a `feature/*` branch into its own `epic/*` branch.

## Sub-agent worktrees

Sub-agents spawned by `/harness:workstream` each get their own worktree, created by the orchestrator, which passes its absolute path to the agent as `project_root`:

- `.claude/worktrees/<milestone>/<workstream-id>/` when the workstream is milestone-scoped
- `.claude/worktrees/<workstream-id>/` for ad-hoc issue-list workstreams

Without an issue tracker there are no milestones: `/harness:workstream` agrees a slug with the user, and the slug takes the milestone's place in every path and branch name here (`integration/<slug>`, `.claude/worktrees/<slug>/...`).

The milestone prefix lets two parallel orchestrator sessions work on different milestones without colliding. Worktrees are created with `git worktree add --detach <path> <base>`, so the agent starts on a detached HEAD at the base and creates its own branch from there.

Sub-agents commit on their branch but never merge it into `integration/*` or `dev`. The orchestrator merges each finished sub-agent branch into `integration/<milestone>`; landing on `dev` is a user-initiated step.

## Never check out in the main repo during setup

Don't run `git checkout dev` (or any checkout) in the main working tree during `/harness:workstream` setup. The orchestrator works against `origin/dev` and the integration branch directly, so two parallel sessions can run setup concurrently without racing on `.git/index.lock`. Switching branches in the main tree is only acceptable for a merge the user explicitly asked for.

# Integration branches

An `integration/*` branch is where several work branches batch up before going to `dev`. There are two flavours with different lifetimes; the shape is the same and both can coexist.

## Flavour 1 — Ephemeral batching (multiple ready branches into one dev merge)

When several branches are ready **at the same time**, merging each one individually into `dev` is repetitive and runs the merge gates repeatedly. Batch them on a one-shot integration branch, handle conflicts there, then merge that into `dev` once.

### When to use

- 2 or more `feature/*` / `bug/*` / `test/*` / `refactor/*` branches are ready to land at once.
- Their file sets are reasonably disjoint, OR overlap in a way that's easier to reconcile in one place than across N successive dev merges.

For a single ready branch, merge it directly into `dev`. No integration branch needed.

### How

1. **Pick an integration id.** Date-stamped (`integration/2026-05-02`) or topic-stamped (`integration/settings-cluster`) — whichever reads better. The branch is throwaway; name it for legibility.
2. **Create the integration branch off the current `origin/dev`**, in its own worktree.
3. **Merge each ready branch into the integration branch** with `--no-ff`. Each merge stays a discrete commit, so per-branch history survives when the integration branch lands on `dev`.
4. **Resolve any conflicts in place** on the integration branch, committing the resolution.
5. **Merge the integration branch into `dev`** via harness:merge-handler.
6. **Tear down.** Delete the integration branch (local and remote) and remove its worktree and any sub-agent worktrees.

## Flavour 2 — Per-milestone staging (long-lived, for parallel milestones)

When `/harness:workstream` runs against a milestone, sub-agent branches stage on a long-lived `integration/<milestone>` branch (e.g. `integration/1.1.0`) instead of going straight to `dev`. The branch lives for the duration of the milestone and merges into `dev` once, when the milestone is complete.

This lets two milestones run in parallel without mixing in `dev`. Each milestone sees only its own sub-agent work in its integration branch; `dev` sees only finished milestones.

### When this gets used

- `/harness:workstream <milestone>` creates and uses these automatically. You normally don't create them by hand.
- Outside a workstream, reach for this pattern any time a long-running stream of related branches shouldn't reach `dev` until the whole stream is ready (the same situations that would warrant a long-lived `epic/*` branch).

### How

1. **Branch and worktree** are created once per milestone, off `origin/dev`, and pushed with `-u`:
   - Branch: `integration/<milestone>`
   - Worktree: `.claude/worktrees/<milestone>/integration/`
2. **Sub-agent worktrees branch from `integration/<milestone>`**, not directly from `dev`, so later sub-agents in the same milestone see the work of earlier ones.
3. **As each sub-agent finishes**, the orchestrator merges its branch into `integration/<milestone>` inside the integration worktree, via harness:merge-handler. `--no-ff`; conflicts resolved there.
4. **Periodically merge `dev → integration/<milestone>`** to stay current with anything else that lands on `dev` (other milestones, hotfixes, ad-hoc work). Do it whenever `dev` moves and you want to surface conflicts early.
5. **When the milestone is complete**, merge `integration/<milestone> → dev` via harness:merge-handler, which runs the full test suite first. One merge, one coherent diff for the whole milestone.
6. **Tear down.** Delete the integration branch (local and remote) and remove the integration worktree: `git worktree remove .claude/worktrees/<milestone>/integration`.

### Worktree layout

```
.claude/worktrees/
  <milestone>/
    integration/         ← long-lived, on integration/<milestone>
    <workstream-id>/     ← per sub-agent, on its feature/*, epic/* or test/* branch
    <workstream-id>/
  <other-milestone>/
    integration/
    ...
  <workstream-id>/       ← ad-hoc workstream, branched from origin/dev
```

## Conflict semantics (both flavours)

Integration branches are usually conflict-free because the orchestrator launches sub-agents on intentionally disjoint file sets. When a conflict does happen, resolve it on the integration branch so the resolution lands as a single commit rather than spread across several dev merges. Files that commonly conflict in a given project are listed in its `## Harness: conflict hotspots` section of `CLAUDE.md`; check those first when reviewing parallel work.

For per-milestone integration, conflicts also surface between milestone work and other branches landing on `dev` — those resolve when you merge `dev → integration/<milestone>`.

# What NOT to do

- Do not merge into `dev`, `integration/*` or `main` outside the harness:merge-handler skill. Sub-agents don't merge into them at all.
- Do not open PRs — use the harness:merge-handler skill.
- Don't keep ephemeral `integration/*` branches alive once they've landed on `dev`.
- Don't keep `integration/<milestone>` branches alive once the milestone has landed on `dev`. They're long-lived but not permanent — tear them down at milestone close.
- Don't check out branches in the main working tree during `/harness:workstream` setup.
