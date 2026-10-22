---
description: Plan and run parallel dev/test subagent workstreams for a milestone or set of issues
argument-hint: <milestone | issue numbers>
---

Execute a workstream for the following milestone or issues: $ARGUMENTS

Arguments can be:
- A **milestone** name or number (e.g., `"Milestone 3"` or `0.6.9`) — resolves all issues in that milestone
- **Issue numbers** (e.g., `64 65 36`) — can be epics (with sub-issues) or standalone issues

## Step 1: Resolve inputs to a flat list of work items

- Use the **harness:ticket-handler** skill to resolve the input:
  - **Milestone**: use `list-issues.sh --milestone` to get all issues, then `--all` variant to include closed.
  - **Issue numbers**: use `list-sub-issues.sh` to expand epics into their sub-issues.
- For each issue that has the `epic` label, expand it into its sub-issues. The epic itself is not a work item — only its sub-issues are.
- For each issue that is NOT an epic, treat it as a standalone work item.
- Filter out closed issues — only open issues are actionable work.
- Read the full text of all actionable issues using `read-issues.sh`.
- Use `get-project-fields.sh` to get the Size and Status of each issue.

## Step 2: Organize into workstreams

Group the actionable issues into workstreams based on these principles:

1. **Sub-issues within the same epic are a natural workstream.** They share context and often have internal dependencies. Keep them together unless the epic is very large (6+ issues) and/or has clearly independent sub-groups and workstreams.
2. **Standalone issues** (not part of any epic) can be grouped with related work or form their own workstream.
3. **Dependencies between workstreams**: if issues across different epics have dependencies, note this and sequence those workstreams accordingly.
4. **Prefer fewer, larger workstreams** over many small ones. One agent handling 3 related issues sequentially is better than 3 agents each doing 1 issue.

## Step 3: Assign agent types

For each workstream, assign an agent type based on the Size field and labels of its issues:
- **Label `test`**: `harness:test-agent` (regardless of size)
- **Small or Medium**: `harness:dev-agent-sm`
- **Large**: `harness:dev-agent-lg`
- Mixed sizes within a workstream: use the larger agent type

## Step 4: Present plan and get approval

Present the full plan to the user:
- List each workstream with its issues, epic (if applicable), agent type, and execution order
- Note any dependencies between workstreams
- Note any standalone issues not in an epic
- Wait for explicit approval before proceeding

## Step 5: Execute sub-agents

Do NOT use agent teams for code-writing workstreams. Do NOT use the Agent tool's `isolation: "worktree"` option either — both have isolation bugs that cause merge conflicts and corrupted working trees.

Instead, **the orchestrator creates the worktree itself** before spawning the sub-agent, and passes the worktree path to the agent in the prompt. The agent runs without any isolation flag and operates inside the pre-created worktree.

**All sub-agents in this step MUST be spawned as background agents** — pass `run_in_background: true` to every Agent tool call. Never spawn a workstream sub-agent in the foreground; foreground spawning blocks the orchestrator on a single workstream and defeats the point of parallelism. You will be notified when each background agent finishes — do NOT poll, sleep, or proactively check on them.

**Independent workstreams** (no dependencies between them) MUST run in **parallel** — spawn all of them in a single message with multiple background Agent tool calls. **Dependent workstreams** must still be spawned in the background, but sequentially: wait for the upstream agent's completion notification before spawning the next.

For each workstream:

1. **Set status to In Progress**: use `set-status.sh` to move all issues in the workstream to "In Progress".

2. **Create a worktree** from the main repo, based on `dev`:
   - Make sure `dev` is up to date first: `git fetch origin && git checkout dev && git pull`.
   - Pick a workstream id: the epic issue number if applicable, otherwise the hyphen-joined issue numbers (e.g. `42-43-44`).
   - Worktrees live inside the project at `.claude/worktrees/<workstream-id>` (relative to the repo root). Add `.claude/worktrees/` to `.gitignore` if it isn't already.
   - Run: `git worktree add <repo-root>/.claude/worktrees/<workstream-id> dev` using the absolute path.

3. **Spawn the sub-agent** via the Agent tool. **MUST pass `run_in_background: true`** (background agent). **Do NOT pass `isolation: "worktree"`**. The prompt MUST begin with a `project_root:` line giving the absolute worktree path, followed by the `/harness:issue` invocation. Example:
   ```
   project_root: /home/user/code/meal-planner-app/.claude/worktrees/42

   /harness:issue 22, 23, 38
   ```
   The agent will cd to `project_root` and do all work there.

4. After receiving the background agent's completion notification, verify it produced commits on a `feature/*` or `epic/*` branch inside the worktree:
   ```
   git -C <absolute-worktree-path> log --oneline dev..HEAD
   git -C <absolute-worktree-path> status
   ```
   If there are no commits, or the branch is still `dev`, stop and flag it to the user — the agent likely operated in the wrong directory.

5. Review what the agent did — read comments on issues, check for concerns. Flag any concerns to the user before continuing.

Do NOT merge branches during this step. Sub-agents write code only — merging happens in Step 6.

## Step 6: Merge

After **all** sub-agents have completed, merge their branches into `dev` and clean up the worktrees:

1. For each workstream, push the agent's branch from inside its worktree if it isn't already pushed: `git -C <worktree-path> push -u origin <branch>`.
2. Merge each completed branch into `dev` per the **harness:merge-handler** skill. Resolve conflicts, push, and delete the branches (local and remote).
3. Remove each worktree once its branch is merged: `git worktree remove <absolute-worktree-path>`. If the worktree has uncommitted state, investigate before forcing — do not pass `--force` reflexively.
4. Review changes across workstreams for consistency and integration. Fix any cross-workstream issues (e.g., missing struct fields, changed function signatures).
5. **Set status to Staged**: use `set-status.sh` to move all merged issues to "Staged".
6. Do not open PRs to main. Do not ask the user if they want to open a PR.
