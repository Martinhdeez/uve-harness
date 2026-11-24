# Brief: <ID> <title>

- **Role:** builder | test-author | designer | assistant | devops
- **Weight:** light (no reviewer; the gate is the proof) | full
- **Iteration:** `docs/plan/<NN-slug>/`
- **Branch:** `<type>/<slug>` from `<integration branch>`

## Goal

<The problem or the behaviour wanted, in two or three sentences.>

## Measured against

<The requirement ids (REQ-…), the contract section, the ADR or the rule this is judged by.>

## In scope

<Files or folders this agent may change, one per line (globs allowed). Before your first edit,
copy this list to `.scratch/scope`: `gh pr create` is denied if the branch changes anything
outside it. If something outside must change, stop and report.>

## Where to look

<Entry points the orchestrator already read, as `file:line` with one line on why each matters.
Builder, designer, devops and assistant briefs only. **Never in a test author's brief**: it
would show the implementation it must not see.>

## Closed

<What must not be changed, and for a test author what must not be read.>

## Proof

<The test that must fail before and pass after, the evidence to save under
`.scratch/after/<slug>/`, any check beyond the gate (build, e2e, a run on the installation).>

## Change note

`.artifacts/to-test/YYYY-MM-DD-<slug>.md`, from `templates/change-note.md`.
