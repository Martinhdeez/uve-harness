// OpenCode plugin of the harness: the same three machine rules as hooks/hooks.json, decided
// by scripts/guard.py, plus bin/ on the PATH of every shell so harness-gate and harness-trace
// resolve. setup-opencode.sh links this file into ~/.config/opencode/plugins/.
import { spawnSync } from "node:child_process"
import { realpathSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const root = dirname(dirname(realpathSync(fileURLToPath(import.meta.url))))
const guard = join(root, "scripts", "guard.py")
const TOOLS = { shell: "Bash", bash: "Bash", read: "Read", grep: "Grep" }

// guard.py speaks the Claude Code hook protocol; translate the call into it.
// Not exported: OpenCode loads every export of a plugin file as a plugin.
function check(tool, args, directory) {
  const name = TOOLS[tool]
  if (!name) return
  const path = args.path ?? args.filePath ?? ""
  const event = {
    tool_name: name,
    tool_input: { command: args.command ?? "", file_path: path, path },
    cwd: args.workdir ?? directory,
  }
  const run = spawnSync("python3", [guard], { input: JSON.stringify(event), encoding: "utf8" })
  if (!run.stdout?.trim()) return
  const out = JSON.parse(run.stdout).hookSpecificOutput
  // OpenCode cannot ask from a plugin, so "ask" blocks too: the user runs that command.
  if (out.permissionDecision === "deny") throw new Error(out.permissionDecisionReason)
  if (out.permissionDecision === "ask")
    throw new Error(out.permissionDecisionReason + " Ask the user to run it themselves.")
}

export const Harness = async ({ directory }) => ({
  "tool.execute.before": async (input, output) => check(input.tool, output.args ?? {}, directory),
  "shell.env": async (input, output) => {
    output.env.PATH = `${join(root, "bin")}:${output.env.PATH ?? process.env.PATH}`
  },
})
