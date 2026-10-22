---
name: merge-handler
description: Merge and release workflow. Handles merging work branches into integration/<milestone> or dev, landing a finished milestone's integration branch on dev behind a full-test-suite gate, opening the dev → main release PR, and — once the user confirms approval — merging it, pushing an annotated version tag, and closing the milestone. Use when the user asks to merge a branch, open a release PR, or complete a milestone.
---

Project-specific inputs come from the project's `CLAUDE.md` (see "Project contract" in the harness README): `## Harness: quality gates`, `## Harness: lockfile`, `## Harness: user-only checks`, and `## Harness: conflict hotspots`. Each section below says what to do when one is missing.

Issue tracking is optional. Before any tracker step, run `harness-tracker-status` once with the Bash tool. With a tracker, the tracker steps below use `harness-tracker` (see the harness tracker contract, `contracts/tracker.md` in the harness plugin); without one, skip them — everything else, including the release flow, works the same. Without a tracker, `<milestone>` in branch and worktree names is the slug agreed in `/harness:workstream`.

Every step here is user-initiated. Only merge, open release PRs, merge release PRs or push tags when explicitly asked.

# Common rules for every merge

- **Confirm location first.** Run `pwd` and `git branch --show-current` before anything else; sessions drift into agent worktrees. Each merge type below says where it must run. Merges into `dev` run from the main repo root (not a `.claude/worktrees/*` path); merges into `integration/<milestone>` run inside that milestone's integration worktree.
- **Pull with `--ff-only`** before merging, so a diverged local branch fails loudly instead of creating a stray merge.
- **Merge with `--no-ff`**, so each landed branch stays a discrete merge commit.
- **If a pre-merge hook fails:** abort (`git merge --abort`), fix the cause on the source branch (in its worktree), and retry. If the hook needs a prerequisite that isn't available (a service, a container runtime, a database), ask the user to start it. Never bypass with `--no-verify` unless the user explicitly says to.
- **Lockfile hygiene.** If the source branch changed the project's lockfile (named in `## Harness: lockfile`; if that section is missing, recognise the lockfile of the project's package manager), check the lockfile diff for unrelated version bumps before merging. Adding or removing one dependency can re-resolve unrelated packages. Prefer restoring the target branch's lockfile and re-running the reinstall command from the project contract, so the diff contains only the intended change.
- **Conflicts.** Resolve them locally on the target branch and commit the resolution. Files listed in `## Harness: conflict hotspots` are the usual suspects; if a resolution needs a judgement call about behaviour, ask the user.
- **Never force push.**

# Merging a sub-agent branch into `integration/<milestone>`

Used for milestone workstreams, after `/harness:workstream` hands off its manifest. This happens entirely inside the integration worktree — never switch branches in the main repo for it.

1. `cd <repo-root>/.claude/worktrees/<milestone>/integration` and confirm `git branch --show-current` is `integration/<milestone>`.
2. `git fetch origin && git pull --ff-only`.
3. Merge the sub-agent branch (it is a local branch of the same repo, so no fetch is needed): `git merge --no-ff <branch>`. Apply the common rules above for hooks, lockfile, and conflicts.
4. `git push` (the integration branch already tracks `origin/integration/<milestone>`).
5. Remove the sub-agent worktree: `git worktree remove <repo-root>/.claude/worktrees/<milestone>/<workstream-id>`. If it has uncommitted state, investigate before forcing — don't pass `--force` reflexively.
6. Delete the sub-agent branch, locally and on the remote if it was pushed. `git branch -d` may refuse because the branch isn't merged into the main repo's HEAD; confirm with `git merge-base --is-ancestor <branch> integration/<milestone>` and then use `git branch -D`. Remote: `git push origin --delete <branch>`.

To pick up work that landed on `dev` since the milestone started, merge `dev → integration/<milestone>` the same way (steps 1–4, merging `origin/dev`). Do this whenever `dev` moves and conflicts should surface early.

# Landing a milestone: `integration/<milestone>` → `dev`

Used once, when every sub-agent branch for the milestone has landed on the integration branch and the user says the milestone is complete.

1. **Full-suite gate, inside the integration worktree.** First merge the latest `origin/dev` into `integration/<milestone>` (see above) so the gate runs on what `dev` will actually contain. Then run every command listed in `## Harness: quality gates` — typecheck, format check, lint, and the **full** test suite including slower tiers such as integration tests. This is the "suite at milestone close" gate that harness:test-agent relies on: test branches may have been pushed red while implementation was in flight, and this is where that gets settled.
   - If a gate needs a prerequisite (a running service, a container runtime), ask the user to start it.
   - Do **not** run anything listed in `## Harness: user-only checks`.
   - If the project has no quality-gates section, ask the user which commands make up the full suite before proceeding.
   - If anything fails, stop and report the failures as findings (which test, which issue it belongs to). Don't weaken tests or patch code to get green without the user's go-ahead.
2. **Move to the main repo root** and confirm `pwd`. Switching the main tree to `dev` is fine here, because this merge is user-initiated (it's only forbidden during workstream setup). If the main tree has uncommitted changes, or `dev` is checked out in another worktree, stop and ask.
3. `git switch dev && git pull --ff-only`.
4. `git merge --no-ff integration/<milestone>`, applying the common rules above.
5. `git push origin dev`.
6. **Tear down:** remove the integration worktree (`git worktree remove <repo-root>/.claude/worktrees/<milestone>/integration`), remove any sub-agent worktrees still left under `.claude/worktrees/<milestone>/`, then delete `integration/<milestone>` locally and on the remote.

# Merging an ad-hoc branch into `dev`

Used for branches from ad-hoc workstreams (branched from `origin/dev`), branches the user made by hand, and one-shot `integration/*` batches (see harness:git-flow).

1. Confirm `pwd` is the main repo root, not a `.claude/worktrees/*` path. If the main tree has uncommitted changes, stop and ask.
2. `git switch dev && git pull --ff-only`.
3. `git merge --no-ff <branch>`, applying the common rules above.
4. `git push origin dev`.
5. If the branch lived in a worktree, remove it: `git worktree remove <absolute-worktree-path>` (investigate uncommitted state before forcing).
6. Delete the source branch, locally and on the remote if it was pushed.

# Releases: every `dev` → `main` PR is a numbered release

Each PR from `dev` to `main` ships as a version, and each version gets an annotated tag `vX.Y.Z` when the PR merges. Untagged releases are what this process exists to prevent.

## Picking the version

- **The PR closes out a numbered milestone** (e.g. milestone `1.4.0`): the version is that milestone's number.
- **No tracker:** there is no milestone to read a number from. Propose the next version from the latest release (below) and the size of the change, and let the user decide.
- **Otherwise** (a fix batch, or leftovers from an already-shipped milestone): use the next patch after the latest release. Find the latest release from both `git tag --sort=-v:refname` and the titles of recent merged PRs into `main`, because older releases may be untagged.
- **Always confirm the version with the user** before opening the PR.
- **Check the tag is free:** `git tag -l vX.Y.Z` locally and `git ls-remote --tags origin vX.Y.Z` on the remote.

## Opening the release PR

Only when the user asks.

1. `git fetch origin`. If `dev` lacks commits from `main` other than PR merge commits (e.g. a hotfix), merge `origin/main` into `dev` and resolve conflicts locally.
2. **Remind the user to run the project's user-only checks** (`## Harness: user-only checks`) before the PR. Agents must not run them. Wait for the result, or record in the PR body that they haven't been run. If the section is missing, skip this step.
3. Open the PR `dev` → `main`:
   - **Title:** `X.Y.Z: <short theme>`
   - **Body:**
     - `## X.Y.Z: <theme>`, naming the release version and the milestone (or slug) it closes
     - `### What's in it`: one bullet per work item or change, with tracker refs when there is a tracker
     - `### Verification`: what actually ran and passed (merge gates, test counts, build, user-only checks if the user reported them)
     - `### Not verified`: anything left for the user, such as manual device checks or visual review
     - No Claude/Anthropic attribution line (see Constraints).
4. **Stop and wait** for the user to confirm the PR is approved.

## After approval

Do these in order, and report each result:

1. **Merge the PR:** `gh pr merge <n> --merge`. Don't squash or rebase; `main`'s history is merge commits.
2. **Tag the merge commit:**
   - `git fetch origin`, then find the merge commit: `gh pr view <n> --json mergeCommit --jq .mergeCommit.oid`.
   - Create an annotated tag on that SHA:
     ```
     git tag -a vX.Y.Z <sha> -F <message-file>
     ```
     The message file's first line is `Release X.Y.Z`, then a blank line, then a one-line theme, then `- ` bullets summarising the release.
   - `git push origin vX.Y.Z`. Push only that tag, never `--tags`.
3. **Tracker: close out the milestone.** Skip this step without a tracker. Dry run first and show the user the list:
   ```
   harness-tracker close-milestone "<milestone>" --dry-run
   ```
   If an open item in the milestone didn't actually ship, move it to another milestone in the tracker before going on. Then run it for real:
   ```
   harness-tracker close-milestone "<milestone>"
   ```
   This closes the milestone's open items, moves all of its items to `complete`, and closes the milestone itself. Epic statuses are the tracker's job: it rolls them up from their sub-issues, and leaves open any epic with unfinished sub-issues in another milestone (the dry run lists these). If it exits `3` (unsupported by the tracker module), tell the user the tracker bookkeeping is theirs to do.
4. **GitHub Release:** only if the user asks for one (`gh release create vX.Y.Z --verify-tag --notes-file <file>`). The tag is the default deliverable.

# Constraints

- Only merge to `dev` or `integration/*`, open PRs to `main`, merge release PRs or push tags when explicitly asked. A request like "open the release PR and tag it when it merges" covers the whole release sequence, but still stop for the approval confirmation.
- Never force push. Never move or delete a pushed tag; if a tag is wrong, tell the user and agree on a new patch version.
- Never attribute commits, merge commits, PRs, tags or releases to Claude or Anthropic. No `Co-Authored-By` trailers and no "Generated with Claude Code" lines, even if a session reminder supplies them. The harness version-control rule takes precedence.
