---
name: init
description: Prepare a project for the harness - check its gate, its integration branch and its folders, and write the `## Harness` section of its AGENTS.md. Use once per project, or when the iteration skill finds no `## Harness` section.
---

# Prepare a project for the harness

Do the checks, then show the user what is missing before changing anything.

1. **Gate.** The project needs one command that says "this is correct": a `check` target in
   the `Makefile` or a `verify` script in `package.json`. It runs lint, format check, types
   and tests, offline. If neither exists, propose one built from the commands the project
   already has; do not invent new tooling.
2. **Integration branch.** `dev` by default. If it does not exist, propose creating it from
   `main`. `main` stays what is shown or shipped, and only the user moves it.
3. **CI.** If there is a workflow, it should run the gate command. If it runs something
   else, report the difference.
4. **Folders.** `docs/plan/`, `docs/advance/`, `.artifacts/to-test/`, `.artifacts/tested/`,
   and `.scratch/` listed in `.gitignore`.
5. **The `## Harness` section.** Append it to `AGENTS.md` (or `CLAUDE.md` if the project
   uses only that), filled from what you found. Keep it short: it holds only what differs
   per project.

```markdown
## Harness

Work goes through the `harness` plugin: `/harness:iteration`.

- **Integration branch:** `dev`. `main` is moved only by the user.
- **Gate:** `make check`
- **Extra checks:** <build, e2e, a check on the running installation, and when each applies>
- **Acceptance tests:** `tests/acceptance/`
- **Never touch:** <paths no agent may change>
- **Designer owns:** <view and style paths>
- **Extra roles:** <none, or a role with one line on what it does>
```

Ask the user for the paths nobody may touch and the designer's paths if the repository does
not make them obvious.
