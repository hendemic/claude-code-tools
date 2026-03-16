Execute a workstream for the following milestone or issues: $ARGUMENTS

- Use the **ticket-handler** skill to pull and read all issues (if a milestone, resolve by pattern match).
- Analyze dependencies between issues and group them into workstreams that can be worked on in parallel. Order dependent workstreams sequentially.
- For each workstream, assign an agent type based on the Size field of its issues:
  - **Small or Medium**: `dev-agent-sm`
  - **Large**: `dev-agent-lg`
  - Mixed sizes: use the larger agent
- Present the full plan to the user — workstreams, issues, dependencies, execution order, and agent assignments. Wait for explicit approval before proceeding.
- Spawn dev agents for each workstream in agent team, using the issue command and issue numbers as a prompt (e.g. "/issue 1, 2, 5"). Run independent workstreams in parallel, dependent ones sequentially.
- Once all agents complete, read the agent comments on each issue to understand what was done, key decisions, and any flagged concerns. Review changes across workstreams for consistency and integration. Flag any concerns to the user.
- Merge each completed branch into `dev` per the **merge-handler** skill. Resolve conflicts, push, and clean up branches.
- Do not open PRs to main. Do not ask the user if they want to open a PR. Do not close issues.
