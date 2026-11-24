# harness

My way of building software with agents, as a Claude Code plugin: iterations of an
incremental V-cycle, one agent per role, one gate, and three rules a machine enforces.

## Install

```sh
gh repo clone Martinhdeez/uve-harness ~/harness && sh ~/harness/setup.sh
```

`setup.sh` installs the plugin for every project, the status line and the three skills the
agents use. It needs `claude`, `git`, `python3`, `jq` and `npx`, and is safe to run again.

To update: `git -C ~/harness pull`, then start a new session. Self-check: `sh tests/test.sh`.

## Use

In a project, once: `/harness:init`. Then `/harness:iteration` in the session that
orchestrates. The designer can also be a session of its own: `claude --agent harness:designer`.

## OpenCode

The same harness runs on OpenCode v2:

```sh
gh repo clone Martinhdeez/uve-harness ~/harness && sh ~/harness/setup-opencode.sh
```

It writes into `~/.config/opencode/`: the agents as `harness-<role>` subagents (the designer
is also a primary agent), the skills as `harness-init` and `harness-iteration` with a command
each, and `plugins/harness.js`, which runs `scripts/guard.py` before `shell`, `read` and
`grep` and puts `bin/` on the shell's `PATH`. Agents, skills and commands are copies: run the
script again after a pull. Each agent keeps its role's model
(`anthropic/claude-<opus|sonnet>-5-5`); `HARNESS_MODEL` sets one model for all of them.

Differences from Claude Code:

- A plugin cannot ask the user, so a push or merge to `main` is blocked instead of asked. The
  user runs it.
- No worktree isolation for subagents: the brief tells the agent to `git worktree add`.
- No status line.

In a project: `/harness-init` once, then `/harness-iteration`.

## The cycle

```text
 requirements (REQ-…) ───────────────────────────► acceptance tests      (test-author, blind)
        │                                                  ▲
 frozen contracts ───────────────────────────────► written against the contracts only
        │                                                  │
 item plans ──► implementation + unit tests (builder) ──► reconciliation + merge (reviewer)

 views:  prototype (designer) ──► USER APPROVES ──► implementation (designer) ──► reviewer
```

The user approves at three points: the plan of the iteration, each prototype, and the close.

## Roles

| Role | Model | Does | Never |
|---|---|---|---|
| Orchestrator (`skills/iteration`) | the session's | plans, writes one brief per item, launches agents, relays | writes code |
| `builder` | sonnet | one fix or feature, unit tests, evidence, change note, pull request | merges, edits acceptance tests |
| `test-author` | sonnet | acceptance tests from requirements and contracts | reads the implementation |
| `reviewer` | opus | re-runs the gate, proves tests can fail, reconciles, merges into `dev` | fixes implementation, touches `main` |
| `designer` | opus | prototypes the views, then implements them once approved | implements before approval |
| `assistant` | sonnet | docs, scripts, counts, cleanup | changes product behaviour |
| `devops` | sonnet | CI, containers, deploy scripts, environments, backups | touches production unasked |

A strong model judges (reviewer, designer) and cheaper ones execute, so the reviewer is also
not the builder's model. Change a role's `model:` line to move it; the ledger's cost per
item says whether a move paid off.

## What the machine enforces

`hooks/hooks.json` runs `scripts/guard.py` before every `Bash`, `Read` and `Grep`:

| Rule | Effect |
|---|---|
| `gh pr create` without a green gate on the current commit, in a project prepared with `/harness:init` | denied |
| `gh pr create` when the branch changes a file outside `.scratch/scope` (the brief's *In scope*) | denied |
| Reading a `.env*` file that is not an example (also through interpreters, editors, `source`, `.` and `<`) | denied |
| A push or a merge that lands on `main` or `master` | asks the user |

`bin/harness-gate` runs the project's gate (`make check` or `npm run verify`), keeps the full
output in `<git dir>/gate.log`, shows the agent only the failing lines and the tail, and stamps
the commit it passed on. `bin/harness-lane` decides from the diff whether an item may stay
light (paths touched, not lines). `bin/harness-scope` checks a branch against `.scratch/scope`.
`bin/harness-trace` fails when a requirement id has no test naming it.

Everything else (who may read what, the designer's files) is a rule the agents are
given and the reviewer checks; it is not enforced by a hook.

## Status line

`statusline/statusline-command.sh` is my status line: caveman mode, model, effort, folder,
context bar, and the 5-hour and 7-day limits. A plugin cannot set the main status line, so on
a new machine run `sh scripts/install-statusline.sh` once (needs `jq`).

## Skills the agents use when installed

| Skill | Used by | Install |
|---|---|---|
| `tdd` | builder | `npx skills add mattpocock/skills@tdd -g -y` |
| `playwright-best-practices` | test-author, designer | `npx skills add currents-dev/playwright-best-practices-skill@playwright-best-practices -g -y` |
| `web-design-guidelines` | designer | `npx skills add vercel-labs/agent-skills@web-design-guidelines -g -y` |
| `frontend-design`, `redesign-existing-projects`, `ui-ux-pro-max` | designer, one per task | |

The harness works without them; each agent only loads one that is present.

## What a project keeps

Only what differs: the `## Harness` section of its `AGENTS.md` (integration branch, gate,
extra checks, forbidden paths, designer's paths), its invariants and its commands. The
project's file wins over the plugin.

```text
docs/plan/<NN-slug>/     00-plan.md, requirements.md, contracts.md, mocks/, 99-close.md
docs/advance/            checklist-<NN>.md, ledger-<NN>.jsonl (agent, model, tokens, minutes, rounds)
docs/decisions.md        decisions that outlive an iteration, read at every plan
.artifacts/to-test/      change notes waiting for review; moved to tested/ on merge
.scratch/after/<slug>/   evidence, never committed
```
