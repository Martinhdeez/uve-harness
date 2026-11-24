# Working on the harness itself

This repository is a Claude Code plugin (and an OpenCode port) for building software with
agents. `llms.txt` maps every file; read it first and open only what the change needs.

- **Self-check:** `sh tests/test.sh` must pass before every commit. A new rule in a script
  gets a test there that fails without it.
- **Machine rules live in code:** `scripts/guard.py` and `bin/`. Everything in `agents/` and
  `skills/` is prompt. Do not claim a prompt rule is enforced.
- **OpenCode:** `setup-opencode.sh` generates copies of agents and skills; a change to their
  frontmatter or to Claude Code names (`harness:<role>`) must still convert there.
- **Style:** English, short sentences, Conventional Commits. The README is the user's
  documentation; update it when a role, a rule or a script changes.
