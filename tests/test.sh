#!/bin/sh
# Self-check of the gate, the trace and the guard. Run: sh tests/test.sh
here=$(cd "$(dirname "$0")/.." && pwd)
gate=$here/bin/harness-gate
trace=$here/bin/harness-trace
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0

expect() { # expect <name> <wanted> <got>
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: wanted '$2', got '$3'"; fails=1; fi
}
commit() { git -c user.name=t -c user.email=t@t commit -qm "$1" --allow-empty; }
guard() { # guard <tool> <input json> -> allow | ask | deny
  out=$(printf '{"tool_name":"%s","tool_input":%s,"cwd":"%s"}' "$1" "$2" "$PWD" | python3 "$here/scripts/guard.py")
  case $out in *'"ask"'*) echo ask ;; *'"deny"'*) echo deny ;; *) echo allow ;; esac
}
bash_guard() { guard Bash "$(python3 -c 'import json,sys; print(json.dumps({"command": sys.argv[1]}))' "$1")"; }

cd "$tmp" && git init -q -b dev && printf 'check:\n\t@test -f ok\n' > Makefile && git add -A && commit init

# gate
"$gate" --check 2>/dev/null; expect "gate: unstamped commit is refused" 2 $?
"$gate" 2>/dev/null;         expect "gate: red gate exits 1" 1 $?
touch ok && git add -A && commit ok
"$gate" 2>/dev/null;         expect "gate: green gate exits 0" 0 $?
"$gate" --check 2>/dev/null; expect "gate: stamped commit is accepted" 0 $?
echo >> Makefile
"$gate" --check 2>/dev/null; expect "gate: uncommitted change voids the stamp" 2 $?
git checkout -q Makefile && commit next
"$gate" --check 2>/dev/null; expect "gate: a new commit voids the stamp" 2 $?

# guard: gate before a pull request
expect "guard: no gate demanded before /harness:init" allow "$(bash_guard 'gh pr create --base dev --fill')"
printf '# Project\n\n## Harness\n' > AGENTS.md && git add -A && commit harness
expect "guard: gh pr create without a green gate" deny "$(bash_guard 'gh pr create --base dev --fill')"
"$gate" 2>/dev/null
expect "guard: gh pr create with a green gate" allow "$(bash_guard 'git push -u origin feat/x && gh pr create --base dev')"

# guard: secrets
expect "guard: Read .env" deny "$(guard Read '{"file_path":"/p/.env"}')"
expect "guard: Read .env.local" deny "$(guard Read '{"file_path":"/p/backend/.env.local"}')"
expect "guard: Read .env.example" allow "$(guard Read '{"file_path":"/p/.env.example"}')"
expect "guard: Read environment.ts" allow "$(guard Read '{"file_path":"/p/src/.environment.ts"}')"
expect "guard: cat .env" deny "$(bash_guard 'cat .env')"
expect "guard: grep in .env.production" deny "$(bash_guard 'grep KEY backend/.env.production | head')"
expect "guard: cat .env.example" allow "$(bash_guard 'cat .env.example')"
expect "guard: cp .env.example .env" allow "$(bash_guard 'cp .env.example .env')"
expect "guard: compose with an env file" allow "$(bash_guard 'docker compose --env-file .env up -d')"

# guard: main
expect "guard: push a feature branch" allow "$(bash_guard 'git push -u origin feat/main-menu')"
expect "guard: push to main" ask "$(bash_guard 'git push origin main')"
expect "guard: push HEAD:main" ask "$(bash_guard 'git push origin HEAD:main')"
expect "guard: push to master with force" ask "$(bash_guard 'git push --force origin master')"
expect "guard: merge on dev" allow "$(bash_guard 'git merge feat/x')"
git checkout -q -b main
expect "guard: bare push while on main" ask "$(bash_guard 'git push')"
expect "guard: merge while on main" ask "$(bash_guard 'git merge dev')"
expect "guard: merge --abort while on main" allow "$(bash_guard 'git merge --abort')"
expect "guard: other commands on main" allow "$(bash_guard 'git status && git log --oneline -3')"
git checkout -q dev

# trace
mkdir -p tests && cat > requirements.md <<'EOF'
| Id | Requirement |
|---|---|
| REQ-XX1-1 | first |
| REQ-XX1-2 | second, unlike REQ-XX1-1 |
- REQ-XX1-10 tenth
EOF
echo "test('REQ-XX1-1 first', f); test('REQ-XX1-10 tenth', f)" > tests/a.test.ts
out=$("$trace" requirements.md tests 2>/dev/null); expect "trace: a missing requirement exits 1" 1 $?
expect "trace: names only the missing one" "trace: REQ-XX1-2 has no test" "$out"
echo "test('REQ-XX1-2 second', f)" >> tests/a.test.ts
"$trace" requirements.md tests 2>/dev/null; expect "trace: all named exits 0" 0 $?

# status line
home=$tmp/home && mkdir -p "$home/.claude" && echo '{"model":"opus"}' > "$home/.claude/settings.json"
HOME=$home sh "$here/scripts/install-statusline.sh" >/dev/null
expect "statusline: settings point at the script and keep other keys" "bash $home/.claude/statusline-command.sh opus" \
  "$(jq -r '.statusLine.command + " " + .model' "$home/.claude/settings.json")"
out=$(echo '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/a/proj"}}' | HOME=$home bash "$home/.claude/statusline-command.sh")
case $out in *Opus*proj*) expect "statusline: renders model and folder" ok ok ;; *) expect "statusline: renders model and folder" ok "$out" ;; esac

# opencode
xdg=$tmp/xdg && oc=$xdg/opencode
XDG_CONFIG_HOME=$xdg HARNESS_SKIP_SKILLS=1 sh "$here/setup-opencode.sh" >/dev/null 2>&1
expect "opencode: builder is a subagent with a provider model" "mode: subagent|model: anthropic/claude-opus-5-5" \
  "$(grep -E '^(mode|model):' "$oc/agents/harness-builder.md" | paste -sd'|' -)"
expect "opencode: designer can also be a primary agent" "mode: all" "$(grep '^mode:' "$oc/agents/harness-designer.md")"
expect "opencode: no Claude Code names left" "" "$(grep -rl 'harness:\|claude --agent' "$oc" | grep -v plugins)"
expect "opencode: skill renamed with its templates" "name: harness-iteration yes" \
  "$(grep '^name:' "$oc/skills/harness-iteration/SKILL.md") $([ -f "$oc/skills/harness-iteration/templates/brief.md" ] && echo yes)"
expect "opencode: command per skill" "yes" "$([ -f "$oc/commands/harness-init.md" ] && echo yes)"
plugin() { # plugin <tool> <input json> -> allow | block; plugin path -> first PATH entry
  node --input-type=module -e "
    const hooks = {}
    const on = (name) => ({ hook: async (_, fn) => { hooks[name] = fn } })
    const { default: plugin } = await import('$oc/plugins/harness.js')
    await plugin.setup({ tool: on('tool'), shell: on('shell') })
    if ('$1' === 'path') { const e = { env: {} }; hooks.shell(e); console.log(e.env.PATH.split(':')[0]) }
    else try { hooks.tool({ tool: '$1', input: ${2:-0} }); console.log('allow') } catch { console.log('block') }"
}
expect "opencode: plugin blocks reading .env" block "$(plugin read '{"path":"/p/.env"}')"
expect "opencode: plugin allows .env.example" allow "$(plugin read '{"path":"/p/.env.example"}')"
expect "opencode: plugin blocks push to main" block "$(plugin shell '{"command":"git push origin main"}')"
expect "opencode: plugin allows git status" allow "$(plugin shell '{"command":"git status"}')"
expect "opencode: plugin puts bin on PATH" "$here/bin" "$(plugin path)"

exit $fails
