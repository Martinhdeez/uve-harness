# harness

My way of building software with agents, as a Claude Code plugin: iterations of an
incremental V-cycle, one agent per role, one gate, and three rules a machine enforces.

## Install

```sh
claude plugin marketplace add ~/harness
claude plugin install harness@martin                  # every project
claude plugin install harness@martin --scope project  # only the current one
```

After a change here: `claude plugin marketplace update martin`. Self-check: `sh tests/test.sh`.

## Use

In a project, once: `/harness:init`. Then `/harness:iteration` in the session that
orchestrates. The designer can also be a session of its own: `claude --agent harness:designer`.

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

| Role | Does | Never |
|---|---|---|
| Orchestrator (`skills/iteration`) | plans, writes one brief per item, launches agents, relays | writes code |
| `builder` | one fix or feature, unit tests, evidence, change note, pull request | merges, edits acceptance tests |
| `test-author` | acceptance tests from requirements and contracts | reads the implementation |
| `reviewer` | re-runs the gate, proves tests can fail, reconciles, merges into `dev` | fixes implementation, touches `main` |
| `designer` | prototypes the views, then implements them once approved | implements before approval |
| `assistant` | docs, scripts, counts, cleanup | changes product behaviour |
| `devops` | CI, containers, deploy scripts, environments, backups | touches production unasked |

## What the machine enforces

`hooks/hooks.json` runs `scripts/guard.py` before every `Bash`, `Read` and `Grep`:

| Rule | Effect |
|---|---|
| `gh pr create` without a green gate on the current commit, in a project prepared with `/harness:init` | denied |
| Reading a `.env*` file that is not an example | denied |
| A push or a merge that lands on `main` or `master` | asks the user |

`bin/harness-gate` runs the project's gate (`make check` or `npm run verify`) and stamps the
commit it passed on. `bin/harness-trace` fails when a requirement id has no test naming it.

Everything else (scope, who may read what, the designer's files) is a rule the agents are
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
docs/advance/            checklist-<NN>.md
.artifacts/to-test/      change notes waiting for review; moved to tested/ on merge
.scratch/after/<slug>/   evidence, never committed
```
