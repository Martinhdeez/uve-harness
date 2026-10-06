#!/bin/sh
# Installs the status line on a machine that does not have it yet. Needs jq.
# Copies the script to ~/.claude and points settings.json at it; the previous
# settings are kept as settings.json.bak.
set -e
src=$(cd "$(dirname "$0")/.." && pwd)/statusline/statusline-command.sh
dst=$HOME/.claude/statusline-command.sh
settings=$HOME/.claude/settings.json

mkdir -p "$HOME/.claude"
cp "$src" "$dst"
[ -f "$settings" ] || echo '{}' > "$settings"
cp "$settings" "$settings.bak"
jq --arg command "bash $dst" '.statusLine = {type: "command", command: $command}' "$settings.bak" > "$settings"
echo "status line installed: $dst"
