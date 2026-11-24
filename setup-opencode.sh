#!/bin/sh
# Install the harness for OpenCode (v2) from this repository: the role agents, the skills,
# a command per skill and the guard plugin. Safe to run again; run it again after a pull,
# because agents, skills and commands are generated copies. From a fresh machine:
#   gh repo clone Martinhdeez/uve-harness ~/harness && sh ~/harness/setup-opencode.sh
# Each agent keeps its role's model (anthropic/claude-<opus|sonnet|haiku>-5-5); HARNESS_MODEL
# sets one model for all of them.
# HARNESS_SKIP_SKILLS=1 skips installing the third-party skills.
set -e
here=$(cd "$(dirname "$0")" && pwd)
config=${XDG_CONFIG_HOME:-$HOME/.config}/opencode

for tool in git python3; do
  command -v "$tool" >/dev/null || { echo "setup: '$tool' is not installed" >&2; exit 1; }
done
command -v opencode >/dev/null || echo "setup: 'opencode' is not installed yet" >&2

mkdir -p "$config/agents" "$config/skills" "$config/commands" "$config/plugins"

# Claude Code names (harness:builder, claude --agent) become OpenCode ids (harness-builder).
rename='s#claude --agent harness:#opencode run --agent harness-#g; s#harness:#harness-#g'

for file in "$here"/agents/*.md; do
  name=$(basename "$file" .md)
  mode=subagent
  [ "$name" = designer ] && mode=all
  # Each role keeps its own model (opus, sonnet, haiku) unless HARNESS_MODEL sets one for all.
  tier=$(sed -n 's/^model: //p' "$file")
  sed -e '/^name: /d' -e "s#^model: .*\$#mode: $mode\\
model: ${HARNESS_MODEL:-anthropic/claude-$tier-5-5}#" -e "$rename" "$file" > "$config/agents/harness-$name.md"
done

for dir in "$here"/skills/*/; do
  name=$(basename "$dir")
  rm -rf "$config/skills/harness-$name"
  cp -R "$dir" "$config/skills/harness-$name"
  sed -e "s#^name: $name\$#name: harness-$name#" -e "$rename" "$dir/SKILL.md" \
    > "$config/skills/harness-$name/SKILL.md"
  printf -- '---\ndescription: Run the harness-%s skill\n---\n\nLoad the `harness-%s` skill and follow it. Argument: $ARGUMENTS\n' \
    "$name" "$name" > "$config/commands/harness-$name.md"
done

ln -sf "$here/opencode/harness.js" "$config/plugins/harness.js"

# OpenCode also reads ~/.claude/skills and ~/.agents/skills, where `npx skills -g` installs.
if [ -z "$HARNESS_SKIP_SKILLS" ] && command -v npx >/dev/null; then
  for skill in mattpocock/skills@tdd \
    currents-dev/playwright-best-practices-skill@playwright-best-practices \
    vercel-labs/agent-skills@web-design-guidelines; do
    npx -y skills add "$skill" -g -y >/dev/null 2>&1 && echo "skill installed: ${skill##*@}" ||
      echo "setup: could not install $skill" >&2
  done
fi

echo "Done. Open 'opencode' in a project and run /harness-init."
