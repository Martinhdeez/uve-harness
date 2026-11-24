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
5. **Agent instructions and docs index.** Every tool reads the same rules from one place:
   - `AGENTS.md` at the root is the canonical file (Codex, Cursor, Aider and most others read
     it). If the rules live only in `CLAUDE.md`, propose moving them to `AGENTS.md` and
     leaving `CLAUDE.md` as the single line `@AGENTS.md`.
   - If the project has documentation, `AGENTS.md` says where it is and how to find the part
     a task needs (by folder, or by a front matter field such as `module:`), and which
     template a new doc uses.
   - Generated output is never read: if there is a `mkdocs.yml`, `site/` is named as ignored
     in `AGENTS.md` and listed in `.gitignore`. Same for any other docs build folder.
   - `llms.txt` at the root is the map: one line per doc, `- [Title](path): what it covers`,
     grouped by area. Agents read it first and open only what they need. With MkDocs, the
     `mkdocs-llmstxt` plugin can generate it; otherwise write it from the docs that exist.
   - Docs in another repo or on a site: put the URL of its `llms.txt` (or `llms-full.txt`)
     in `AGENTS.md`. A docs MCP server is only worth it when there is a lot of documentation.
6. **The `## Harness` section.** Append it to `AGENTS.md` (or `CLAUDE.md` if the project
   uses only that), filled from what you found. Keep it short: it holds only what differs
   per project.

```markdown
## Harness

Work goes through the `harness` plugin: `/harness:iteration`.

- **Integration branch:** `dev`. `main` is moved only by the user.
- **Gate:** `make check`
- **Extra checks:** <build, e2e, a check on the running installation, and when each applies>
- **Acceptance tests:** `tests/acceptance/`
- **Docs:** <where, and the index: `llms.txt`>. Never read <generated folder, e.g. `site/`>.
- **Never touch:** <paths no agent may change>
- **Designer owns:** <view and style paths>
- **Extra roles:** <none, or a role with one line on what it does>
```

Ask the user for the paths nobody may touch and the designer's paths if the repository does
not make them obvious.
