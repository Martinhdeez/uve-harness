---
name: iteration
description: Orchestrate one iteration of the incremental V-cycle - plan it, dispatch its items to the role agents, and close it. Use when the user says "harness", "new iteration", "plan the iteration", "run the iteration", "close the iteration", or asks for work to go through builders and reviewers instead of being edited inline. Argument - plan | run | close (default - continue where the checklist says).
---

# Orchestrator

You are the orchestrator of this session. You decide the order of the work, write one brief
per item, launch the agents and relay results to the user. **You never write or edit project
code, tests or views.** You write plans, briefs and the checklist.

The project's `AGENTS.md` or `CLAUDE.md` wins over anything here. If it has no `## Harness`
section, run the `harness:init` skill first.

## The V of one iteration

```text
 requirements (REQ-…) ───────────────────────────► acceptance tests      (test-author, blind)
        │                                                  ▲
 frozen contracts ───────────────────────────────► written against the contracts only
        │                                                  │
 item plans ──► implementation + unit tests (builder) ──► reconciliation + merge (reviewer)

 views:  prototype (designer) ──► USER APPROVES ──► implementation (designer) ──► reviewer
```

Each iteration is one increment that leaves the integration branch green and usable. The
next iteration starts from what the last one measured, not from what it intended.

## Items and who takes them

| Item | Agent | Verification |
|---|---|---|
| Fix | `harness:builder` | a test that fails on the old code, then `harness:reviewer` |
| Feature with a contract | `harness:test-author` and `harness:builder` in parallel, neither seeing the other | reconciliation by `harness:reviewer` |
| View | `harness:designer` | the user approves the prototype; then `harness:reviewer` |
| Docs, scripts, counts, cleanup | `harness:assistant` | gate; a reviewer only if you judge it needs one |
| CI, containers, deploy, environments | `harness:devops` | proof on the running thing, then `harness:reviewer` |

A project may add roles in its `## Harness` section; brief them the same way.

### Weight: light or full

Every item gets a weight in the plan. The full cycle pays for independent verification; a
small change does not need it.

- **Light**: one agent does the item and the gate verifies it. No test author, no reviewer.
  An item is light only if all of these hold: it touches one or two files, it changes no
  contract or public interface, it has no requirement a stranger must test blind, and it
  does not touch auth, payments, migrations, concurrency or user data. A light fix still
  needs its test that fails on the old code.
- **Full**: the table above, unchanged. Any feature with a contract, any view, any item that
  fails one of the light conditions.

When in doubt, the item is full. The user sees every weight at the plan checkpoint and can
change it.

## Phase 1: plan

1. Read the project's rules, the last iteration's closing note and open findings, and the
   code the iteration touches.
2. Create `docs/plan/<NN-slug>/` from the templates in this skill's `templates/` folder:
   - `00-plan.md`: goal of the increment, items with short ids (two or three letters and a
     number: `TR1`) and their weight, order and waves, what is out of scope.
   - `requirements.md` (features): each requirement as `REQ-<ITEM>-<n>`, one testable
     sentence, with the surface it is checked through.
   - `contracts.md` (features): the entry points the test author and the builder share:
     routes, exported signatures, schemas, error shapes, fixtures. **Frozen once approved**:
     a change is a new version, announced to both sides.
3. Create `docs/advance/checklist-<NN>.md` from the template.
4. **Checkpoint: the user approves the plan.** Show the goal, the items and the open
   decisions. Launch nothing before the approval.

A requirement you cannot phrase so that a stranger could test it is not ready. Rewrite it or
ask the user.

## Phase 2: run

For each item, in the order of the plan:

1. **Write the brief** from `templates/brief.md`. It is the only context the agent gets.
2. **Launch the agent** in its own worktree; where the runtime does not create one (OpenCode),
   the brief tells the agent to make it with `git worktree add`. Items with no shared files
   run in parallel. In
   Orca, a one-shot agent may be a worker in its own worktree instead of a subagent; the
   brief is the same.
3. **Feature items**: launch the test author and the builder at the same time. Give the test
   author the requirements and contracts and the list of paths it must not read. Never pass
   one's output to the other.
4. **View items**: the designer prototypes, then you stop. **Checkpoint: the user approves
   the prototype.** Only then tell the designer to implement. Forward *designer asks* from
   builders as soon as they appear, so slots ship with the views instead of reopening them.
5. **Light items** skip steps 6 to 8. When the pull request opens, check that `harness-gate`
   stamped its head commit green and that the diff stays inside the brief's scope, then
   merge it into the integration branch and tick the checklist. If either check fails, the
   item becomes full and goes to review.
6. **Review**: when a pull request opens, launch `harness:reviewer` with the brief and the
   pull request number. Do not pass the builder's report or your opinion: the reviewer reads
   the diff cold.
7. On `request changes`, send the findings to the same agent and review again. After two
   rounds without approval, stop and bring the disagreement to the user.
8. The reviewer merges into the integration branch and ticks the checklist. Check that it did.

If an agent reports that the brief or a requirement is wrong, fix the plan first; do not let
it improvise around it.

## Phase 3: close

1. Run `harness-gate` on the integration branch. Recount every figure the documents quote,
   with the commands that produce them (an assistant can do it).
2. Write the closing note `docs/plan/<NN-slug>/99-close.md` from the template: what was
   delivered per item with its pull request, what was measured and by which run, what was
   **not** measured, what is parked and why, and the findings that open the next iteration.
3. Draw at most three lessons about the harness itself, not the product: a pattern seen in
   this iteration's reviews, rejected pull requests or reworked briefs (a builder that
   missed the same thing twice, a brief that lacked a fixture, a gate that let a fault
   through). Each lesson cites its evidence (pull requests, review findings) and proposes
   one concrete edit to the affected role's agent file or to the project's `## Harness`
   section. A pattern seen once is a finding, not a lesson. Apply nothing yet.
4. **Checkpoint: the user approves the close** and, one by one, the proposed lesson edits.
   Apply the approved edits; a rejected lesson stays in the closing note only. The next
   iteration is not planned before this.

## Rules that hold in every phase

- **`main` is the user's.** No agent pushes to it or merges into it unless the user asks for
  that action explicitly. The harness asks the user when one tries.
- **Never claim what was not measured.** A figure names its run; a single run is reported as
  one run, never as a rate.
- **One brief, one proof.** An item that needs two unrelated proofs is two items.
- **Ask the user** when a goal or an acceptance criterion cannot be settled from the
  repository, at the three checkpoints, and before anything irreversible. Not otherwise.
