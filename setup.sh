#!/bin/sh
# One-command install of the harness on a machine: the plugin, the status line and the
# skills the agents use. Safe to run again. From a fresh machine:
#   gh repo clone Martinhdeez/uve-harness ~/harness && sh ~/harness/setup.sh
set -e
here=$(cd "$(dirname "$0")" && pwd)

for tool in claude git python3 jq npx; do
  command -v "$tool" >/dev/null || { echo "setup: '$tool' is not installed" >&2; exit 1; }
done

claude plugin marketplace add "$here" 2>/dev/null || claude plugin marketplace update martin
claude plugin install harness@martin

sh "$here/scripts/install-statusline.sh"

for skill in mattpocock/skills@tdd \
  currents-dev/playwright-best-practices-skill@playwright-best-practices \
  vercel-labs/agent-skills@web-design-guidelines; do
  npx -y skills add "$skill" -g -y >/dev/null 2>&1 && echo "skill installed: ${skill##*@}" ||
    echo "setup: could not install $skill" >&2
done

echo "Done. Open a new 'claude' session and run /harness:init in a project."
