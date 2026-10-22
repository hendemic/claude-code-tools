---
name: git-flow
description: Git branching workflow and conventions. Reference this when creating branches, deciding where to branch from, and understanding the overall git process.
---

# Branch conventions
Follow branch naming and conventions as defined in the project rules (version-control.md).

# Branching workflow
- `dev` is the central development branch. All work branches from `dev`.
- `feature/*` branches are for individual issues or small changes, branched from `dev`.
- `epic/*` branches group related features. Create from `dev`, then branch `feature/*` off the epic.
- Feature branches merge back into their parent (`epic/*` or `dev` depending on context).
- Only the harness:merge-handler skill handles merging into `dev` and creating PRs to `main`.

# Commit practices
- Make atomic commits as progress is made on larger scopes of work
- Commit messages should be concise and describe intent

# What NOT to do
- Do not merge into `dev` or `main` directly — use the harness:merge-handler skill
- Do not open PRs — use the harness:merge-handler skill
