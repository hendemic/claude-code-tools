# claude-code-tools

A personal Claude Code dev-process harness, packaged as a plugin marketplace named `hendemic-harness`.

| Plugin | What it provides |
| --- | --- |
| `harness` | Skills `development`, `git-flow`, `merge-handler`, `ticket-handler`; commands `/harness:issue`, `/harness:workstream`; agents `harness:dev-agent-sm`, `harness:dev-agent-lg`, `harness:test-agent`; a SessionStart hook that loads the version-control rules |
| `harness-rust` | Skill `rust-conventions` for writing and reviewing Rust |

Everything is namespaced by plugin, e.g. `/harness:workstream 0.6.9` or `harness:ticket-handler`.

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
        "ref": "v0.1.0"
      }
    }
  },
  "enabledPlugins": {
    "harness@hendemic-harness": true,
    "harness-rust@hendemic-harness": true
  }
}
```

Commit `.claude/settings.json`. Once a collaborator trusts the folder, Claude Code fetches the marketplace and loads the plugins; no separate install step is needed.

**Pinned vs floating.** With `"ref": "vX.Y.Z"` the project stays on that release. Leave `ref` out to follow the default branch, picking up whatever version the plugin manifests declare on it.

## Upgrade a pinned project

1. Bump `ref` in `.claude/settings.json` to the new tag.
2. `claude plugin marketplace update hendemic-harness`
3. Start a new session (or `/reload-plugins`).

## Local development

Load a plugin straight from a checkout for one session, without installing it:

```sh
claude --plugin-dir ./plugins/harness --plugin-dir ./plugins/harness-rust
```

Check manifests and components before committing:

```sh
claude plugin validate .
claude plugin validate ./plugins/harness
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
