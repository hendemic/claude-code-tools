Execute a workstream for the following milestone or issues: $ARGUMENTS

- Use the **ticket-handler** skill to pull and read all issues (if a milestone, resolve by pattern match).
- Group issues into workstreams. Prefer grouping related issues into sequential workstreams (one agent handles multiple issues in order) over splitting each issue into its own agent. This keeps the number of parallel agents manageable and avoids multiple rounds of agent spawning. Independent workstreams run in parallel.
- For each workstream, assign an agent type based on the Size field and label of its issues:
  - **Label `test`**: `test-agent` (regardless of size)
  - **Small or Medium**: `dev-agent-sm`
  - **Large**: `dev-agent-lg`
  - Mixed sizes: use the larger agent
- Present the full plan to the user — workstreams, issues, dependencies, execution order, and agent assignments. Wait for explicit approval before proceeding.
- Spawn dev agents for each workstream in agent team, using the issue command and issue numbers as a prompt (e.g. "/issue 1, 2, 5"). Run independent workstreams in parallel, dependent ones sequentially.
  - **Every agent MUST be spawned with `isolation: "worktree"`** so it works on an isolated copy of the repo.
  - After agents are spawned, verify each agent's result includes a `<worktree>` tag confirming isolation was established. If any agent's result is missing this tag, stop and flag it to the user — the agent ran in the main repo and its changes may have corrupted the working tree.
- Once all agents complete, read the agent comments on each issue to understand what was done, key decisions, and any flagged concerns. Review changes across workstreams for consistency and integration. Flag any concerns to the user.
- Merge each completed branch into `dev` per the **merge-handler** skill. Resolve conflicts, push, and clean up branches.
- Do not open PRs to main. Do not ask the user if they want to open a PR. Do not close issues.
