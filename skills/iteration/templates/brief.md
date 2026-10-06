# Brief: <ID> <title>

- **Role:** builder | test-author | designer | assistant | devops
- **Iteration:** `docs/plan/<NN-slug>/`
- **Branch:** `<type>/<slug>` from `<integration branch>`

## Goal

<The problem or the behaviour wanted, in two or three sentences.>

## Measured against

<The requirement ids (REQ-…), the contract section, the ADR or the rule this is judged by.>

## In scope

<Files or folders this agent may change.>

## Closed

<What must not be changed, and for a test author what must not be read.>

## Proof

<The test that must fail before and pass after, the evidence to save under
`.scratch/after/<slug>/`, any check beyond the gate (build, e2e, a run on the installation).>

## Change note

`.artifacts/to-test/YYYY-MM-DD-<slug>.md`, from `templates/change-note.md`.
