#!/usr/bin/env bash
# Link a project's .claude/ directory to the shared config in ~/.claude/
#
# Usage: ~/.claude/setup-project.sh <project-path>
#   e.g: ~/.claude/setup-project.sh /path/to/my-project
#
# Creates <project-path>/.claude/ with symlinks to ~/.claude/{skills,agents,rules,commands}
# and a .git file pointing to ~/.claude/.git for version control.

set -euo pipefail

PROJECT="${1:-$(pwd)}"
CLAUDE_DIR="$PROJECT/.claude"
HOME_CLAUDE="$HOME/.claude"

if [ ! -d "$HOME_CLAUDE" ]; then
    echo "Error: $HOME_CLAUDE does not exist"
    exit 1
fi

mkdir -p "$CLAUDE_DIR"

for dir in skills agents rules commands; do
    if [ -e "$CLAUDE_DIR/$dir" ]; then
        echo "Skipping $dir (already exists)"
    else
        ln -s "$HOME_CLAUDE/$dir" "$CLAUDE_DIR/$dir"
        echo "Linked $dir"
    fi
done

if [ ! -e "$CLAUDE_DIR/.git" ]; then
    echo "gitdir: $HOME_CLAUDE/.git" > "$CLAUDE_DIR/.git"
    echo "Linked .git"
else
    echo "Skipping .git (already exists)"
fi

echo "Done. $CLAUDE_DIR is linked to $HOME_CLAUDE"
