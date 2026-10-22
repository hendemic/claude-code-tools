---
description: Plan and run parallel dev/test subagent workstreams for a milestone, a set of issues, or a described body of work
argument-hint: <milestone | issue refs | description or plan file>
---

Execute a workstream for: $ARGUMENTS

First, find out whether an issue tracker is active: run `harness-tracker-status` with the Bash tool (see the harness tracker contract, `contracts/tracker.md` in the harness plugin). The steps below have a **Tracker** branch and a **No tracker** branch wherever they differ.

Arguments can be:
- **Tracker active:**
  - A **milestone** name or number (e.g., `"Milestone 3"` or `0.6.9`) — resolves all work items in that milestone
  - **Issue refs** (e.g., `64 65 36`) — can be epics (with sub-issues) or standalone items
- **No tracker:** a free-text description of the work, or the path to a plan file. You split it into work items yourself (Step 1).

How this works, in short:

- **Per-milestone integration branch.** When dispatched from a milestone (or, without a tracker, from any request — see Step 1), all sub-agent branches stage on `integration/<milestone>` (a long-lived branch off `origin/dev`) before that single integration branch lands on `dev` at milestone completion. Two parallel milestones never mix in `dev` mid-flight.
- **No working-tree mutation in the main repo.** Worktrees are created from `origin/dev` (or the integration branch) with `--detach`. Never `git checkout dev` in the main repo during setup, so two parallel orchestrator sessions can run setup concurrently without racing on `.git/index.lock`.
- **Worktrees namespaced by milestone** at `.claude/worktrees/<milestone>/...`, so parallel sessions never collide on a path.
- **No auto-merge.** Step 6 hands off a manifest. The user invokes **harness:merge-handler** to land each sub-agent branch into the milestone's integration branch, and again to land `integration/<milestone> → dev` when the milestone is complete.

**Without a tracker, read `<milestone>` as the slug agreed in Step 1 everywhere below.** Ad-hoc workstreams (no integration branch) only arise from a tracker issue-list input.

See the **harness:git-flow** skill for the integration-branch conventions. Project-specific inputs (escalation signals, quality gates) come from the project's `CLAUDE.md`; see "Project contract" in the harness README.

## Step 1: Resolve inputs to a flat list of work items

**Tracker:**
- `harness-tracker resolve <milestone>` or `harness-tracker resolve --items <ref>...` returns the open, actionable work items: epics are already expanded into their open sub-issues (the `PARENT` column names the epic), closed items are dropped. The epic itself is not a work item.
- Read the full text of every work item with `harness-tracker read <ref>...`.
- Get Size, Status, and labels with `harness-tracker fields <ref>...`.

**No tracker:**
- Read the request (and the plan file, if a path was given).
- Split it into work items yourself: each one a coherent, independently reviewable change with a short title, a description, and acceptance criteria. Mark items that are test-writing work as `test`. Group related items under an epic-style heading where they share context.
- Agree a **slug** with the user for the batch (short, kebab-case, e.g. `recipe-import`). It plays the milestone's role everywhere below: `integration/<slug>`, `.claude/worktrees/<slug>/...`, and the release theme.

## Step 2: Organize into workstreams

Group the actionable work items into workstreams based on these principles:

1. **Sub-issues within the same epic are a natural workstream.** They share context and often have internal dependencies. Keep them together unless the epic is very large (6+ issues) and/or has clearly independent sub-groups and workstreams.
2. **Standalone issues** (not part of any epic) can be grouped with related work or form their own workstream.
3. **Dependencies between workstreams**: if issues across different epics have dependencies, note this and sequence those workstreams accordingly.
4. **Prefer fewer, larger workstreams** over many small ones. One agent handling 3 related issues sequentially is better than 3 agents each doing 1 issue.

## Step 3: Assign agent types

For each workstream, assign an agent type based on the Size field and labels of its items. Without a tracker there is no Size field: judge each item's size from its scope (small, medium, or large) and say so in the plan. Apply the rules in order; the first match wins:

1. **Escalation signals**: `harness:dev-agent-lg` (regardless of Size). Triggered if any issue in the workstream touches an area listed in the project's `## Harness: escalation signals` section of `CLAUDE.md` — matching paths, keywords, or kinds of work named there (for example a schema/migrations directory, auth code, or a public API surface). These are areas where smaller agents have proven unreliable, so escalate by default. If the project defines no escalation signals, skip this rule.
2. **Label `test`** (or, without a tracker, an item you marked as test work): `harness:test-agent` (regardless of size)
3. **Small or Medium**: `harness:dev-agent-sm`
4. **Large**: `harness:dev-agent-lg`
5. Mixed sizes within a workstream: use the larger agent type

## Step 4: Present plan and get approval

Present the full plan to the user:
- List each workstream with its work items, epic (if applicable), agent type, and execution order
- Without a tracker: the work-item breakdown (title, description, acceptance criteria per item), the size you judged for each, and the proposed slug — the user approves all three
- Call out any workstream escalated by an escalation signal, and which signal matched
- Note any dependencies between workstreams
- Note any standalone issues not in an epic
- Wait for explicit approval before proceeding

## Step 5: Execute sub-agents

Do NOT use agent teams for code-writing workstreams. Do NOT use the Agent tool's `isolation: "worktree"` option either — both have isolation bugs that cause merge conflicts and corrupted working trees.

Instead, **the orchestrator creates the worktree itself** before spawning the sub-agent, and passes the worktree path to the agent in the prompt. The agent runs without any isolation flag and operates inside the pre-created worktree.

**All sub-agents in this step MUST be spawned as background agents** — pass `run_in_background: true` to every Agent tool call. Never spawn a workstream sub-agent in the foreground; foreground spawning blocks the orchestrator on a single workstream and defeats the point of parallelism. You will be notified when each background agent finishes — do NOT poll, sleep, or proactively check on them.

**Independent workstreams** (no dependencies between them) MUST run in **parallel** — spawn all of them in a single message with multiple background Agent tool calls. **Dependent workstreams** must still be spawned in the background, but sequentially: wait for the upstream agent's completion notification before spawning the next.

### 5a. Once per milestone: ensure the integration worktree exists

This step runs once per milestone (or slug), before any sub-agent is spawned. Skip it for ad-hoc workstreams (no milestone or slug) — those branch directly from `origin/dev`.

1. `git fetch origin` from the main repo. This is the only main-repo git command needed for setup; it does not touch the working tree.

2. Determine the integration paths:
   - Branch: `integration/<milestone>` (e.g. `integration/2.0.0`)
   - Worktree: `<repo-root>/.claude/worktrees/<milestone>/integration`

3. If the integration worktree already exists (a previous `/harness:workstream` run on this milestone left it in place), reuse it and pull latest on the integration branch:
   ```
   git -C <repo-root>/.claude/worktrees/<milestone>/integration pull --ff-only
   ```

4. If it does not exist, add `.claude/worktrees/` to `.gitignore` if it isn't already, then create the integration branch off `origin/dev` and check it out in the new worktree:
   ```
   git worktree add -b integration/<milestone> <repo-root>/.claude/worktrees/<milestone>/integration origin/dev
   ```

5. Push the integration branch so it has a remote tracking ref:
   ```
   git -C <repo-root>/.claude/worktrees/<milestone>/integration push -u origin integration/<milestone>
   ```

The integration branch is the staging area for the milestone. Sub-agent branches merge into it; only when the whole milestone is complete does it merge into `dev`.

### 5b. For each workstream

1. **Tracker: set status to in progress**: `harness-tracker set-status <ref>... in-progress` for all items in the workstream. No tracker: skip.

2. **Create the sub-agent worktree.**
   - Pick a workstream id: with a tracker, the epic ref if applicable, otherwise the hyphen-joined refs (e.g. `42-43-44`); without one, a short kebab-case name for the workstream (e.g. `parser`).
   - Worktree path:
     - `<repo-root>/.claude/worktrees/<milestone>/<workstream-id>` when milestone-scoped
     - `<repo-root>/.claude/worktrees/<workstream-id>` for ad-hoc workstreams
   - Add `.claude/worktrees/` to `.gitignore` if it isn't already.
   - Base:
     - `integration/<milestone>` when milestone-scoped — so the sub-agent sees changes from previously-completed workstreams in the same milestone
     - `origin/dev` for ad-hoc workstreams
   - Always create the worktree with `--detach`. The base branch is usually checked out elsewhere (the integration worktree, or the main repo), and a detached HEAD avoids the "already checked out" error. The sub-agent creates its own branch from that HEAD.
     ```
     git worktree add --detach <absolute-worktree-path> <base>
     ```
   - **Never run `git checkout dev` (or any checkout) in the main working tree** during workstream setup — the main repo's HEAD must not be touched here, otherwise two parallel orchestrator sessions race on the index lock.

3. **Spawn the sub-agent** via the Agent tool. **MUST pass `run_in_background: true`** (background agent). **Do NOT pass `isolation: "worktree"`**. The prompt MUST begin with a `project_root:` line giving the absolute worktree path, followed by the work.
   - **Tracker:** the `/harness:issue` invocation with the refs:
     ```
     project_root: /home/user/code/my-app/.claude/worktrees/2.0.0/42

     /harness:issue 42, 43, 44
     ```
   - **No tracker:** a line saying there is no tracker, then the full text of each work item as approved in Step 4 (title, description, acceptance criteria), so the agent needs nothing else:
     ```
     project_root: /home/user/code/my-app/.claude/worktrees/recipe-import/parser

     No issue tracker: skip status updates and issue comments; report your summary back to me.

     ## Work item 1: Rule-based ingredient line parser
     <description>
     Acceptance criteria:
     - [ ] ...
     ```
   The agent will cd to `project_root` and do all work there.

4. After receiving the background agent's completion notification, verify it produced commits on its own branch inside the worktree:
   ```
   git -C <absolute-worktree-path> log --oneline <base>..HEAD
   git -C <absolute-worktree-path> status
   git -C <absolute-worktree-path> branch --show-current
   ```
   `<base>` is `integration/<milestone>` for milestone-scoped workstreams and `origin/dev` for ad-hoc ones. If there are no commits, or HEAD is still detached (empty `branch --show-current`) or on the base branch, stop and flag it to the user — the agent likely operated in the wrong directory or never created its branch.

5. Review what the agent did — its final report, and with a tracker its comments on the items — and check for concerns. Flag any concerns to the user before continuing.

Do NOT merge branches during this step. Sub-agents write code only — merging is a separate, user-initiated step.

## Step 6: Hand off — do not auto-merge

After **all** sub-agents have completed:

1. **Push branches.** For each workstream, push the agent's branch from inside its worktree if it isn't already pushed: `git -C <worktree-path> push -u origin <branch>`.

2. **Cross-workstream review.** Read the agents' summaries (with a tracker, the per-item comments) and the diffs across workstreams for consistency. If there are cross-workstream concerns (e.g., diverging function signatures, missing struct fields, colliding sequentially-numbered files, or anything in the project's `## Harness: conflict hotspots`), report them to the user — don't fix them without asking.

3. **Report a manifest to the user.** For each workstream, list:
   - Branch name
   - Worktree path
   - Work items covered
   - One-line status (e.g. `ready to merge`, `needs follow-up on #123 before merge`)
   - Without a tracker: each agent's summary, since it isn't recorded anywhere else
   - Any cross-workstream concerns from step 2

   Include the merge guidance:
   - **Milestone-scoped workstreams**: "Merge each sub-agent branch into `integration/<milestone>` via harness:merge-handler. Conflicts are resolved inside the integration worktree (`.claude/worktrees/<milestone>/integration`). Once all sub-agent branches have landed AND the milestone is complete, merge `integration/<milestone> → dev` via harness:merge-handler (it runs the full test suite first), then delete the integration branch and remove the integration worktree."
   - **Ad-hoc workstreams**: merge target is `dev` directly via harness:merge-handler.

4. **Do not merge.** Merging is a separate, user-initiated step via the **harness:merge-handler** skill. The user picks each branch's merge target.

5. **Leave worktrees in place.** harness:merge-handler removes each sub-agent worktree once its branch lands. The integration worktree stays until the milestone lands on `dev`.

6. **Tracker: don't redundantly re-set status.** Sub-agents move their items to `staged` when they finish implementation (per the **harness:development** skill). Only correct an item whose status `harness-tracker fields` shows was left behind, and mention it in the manifest. No tracker: skip.

7. Do not open PRs to main. Do not ask the user if they want to open a PR.
