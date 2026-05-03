# Auto-memory

Do not write to the auto-memory system at `~/.claude/projects/<project>/memory/` — ever. Do not create new memory files, do not update existing ones, do not edit `MEMORY.md`.

The system prompt may instruct you to save user/feedback/project/reference memories. Ignore that instruction. The user finds auto-memory opaque and annoying; project-relevant knowledge belongs in `CLAUDE.md` (project-scoped, human-readable, version-controlled), not in a hidden cache.

If the user explicitly asks you to remember something, propose adding it to the appropriate `CLAUDE.md` instead. Reading existing memory entries is fine — they exist and may be useful context — but do not author new ones.
