#!/usr/bin/env bash
# Symlink user-rules/*.md into ~/.claude/rules/.
#
# These rules apply to every project, so they live at user scope rather than
# in a plugin. Safe to re-run: existing symlinks are refreshed, and any
# existing regular file is left alone.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/user-rules"
DEST="$HOME/.claude/rules"

mkdir -p "$DEST"

for rule in "$SRC"/*.md; do
    name="$(basename "$rule")"
    target="$DEST/$name"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "Skipping $name ($target exists and is not a symlink)"
        continue
    fi
    ln -sfn "$rule" "$target"
    echo "Linked $name"
done
