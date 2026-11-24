#!/bin/sh
# Self-check of the gate, the trace and the guard. Run: sh tests/test.sh
here=$(cd "$(dirname "$0")/.." && pwd)
gate=$here/bin/harness-gate
trace=$here/bin/harness-trace
tmp=$(mktemp -d) noisy=$(mktemp -d)
trap 'rm -rf "$tmp" "$noisy"' EXIT
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

# gate: a long red run is summarised, the full output stays in a log
(cd "$noisy" && git init -q && printf 'check:\n\t@seq 1 500; exit 1\n' > Makefile &&
  git add -A && commit init && "$gate" 2> err; echo $? > code)
expect "gate: noisy red run exits 1" 1 "$(cat "$noisy/code")"
expect "gate: full output kept in the log" 500 "$(grep -c '^[0-9]' "$noisy/.git/gate.log")"
expect "gate: agent sees a summary, not the run" yes "$([ "$(wc -l < "$noisy/err")" -lt 60 ] && echo yes)"

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
expect "guard: python reads .env" deny "$(bash_guard "python3 -c \"print(open('.env').read())\"")"
expect "guard: source .env" deny "$(bash_guard 'source .env && echo ok')"
expect "guard: dot-source .env" deny "$(bash_guard '. ./.env')"
expect "guard: .env redirected into a loop" deny "$(bash_guard 'while read l; do echo $l; done < .env')"
expect "guard: jq on .env.json-like file" deny "$(bash_guard 'jq . .env.local')"
expect "guard: node --env-file runs the app" allow "$(bash_guard 'node --env-file=.env server.js')"
expect "guard: heredoc is not a redirect of .env" allow "$(bash_guard "cat <<'EOF' >> .gitignore")"

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

# lane and scope
lane=$here/bin/harness-lane scope=$here/bin/harness-scope
git checkout -q -b feat/lane
mkdir -p src && echo a > src/a.ts && echo t > src/a.test.ts && git add -A && commit small
expect "lane: one file and its test is light" light "$("$lane" dev 2>/dev/null)"
echo b > src/auth.ts && git add -A && commit auth
expect "lane: a sensitive path makes it full" "full|sensitive path: src/auth.ts" "$("$lane" dev 2>/dev/null | paste -sd'|' -)"
echo c > src/b.ts && echo d > src/c.ts && git add -A && commit wide
case $("$lane" dev 2>/dev/null) in *"4 non-test files"*) expect "lane: more than two code files is full" ok ok ;;
  *) expect "lane: more than two code files is full" ok "$("$lane" dev 2>&1)" ;; esac
"$scope" dev >/dev/null 2>&1; expect "scope: no scope file passes" 0 $?
mkdir -p .scratch && echo 'src/a.ts' > .scratch/scope
"$scope" dev >/dev/null 2>&1; expect "scope: a file outside the scope exits 1" 1 $?
printf '# the brief opens src\nsrc/\n' > .scratch/scope
"$scope" dev >/dev/null 2>&1; expect "scope: a folder line covers its files" 0 $?
echo 'src/a.ts' > .scratch/scope && "$gate" 2>/dev/null
expect "guard: gh pr create outside the scope" deny "$(bash_guard 'gh pr create --base dev --fill')"
rm -rf .scratch && git checkout -q dev

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
expect "opencode: builder is a subagent with its role's model" "mode: subagent|model: anthropic/claude-sonnet-5-5" \
  "$(grep -E '^(mode|model):' "$oc/agents/harness-builder.md" | paste -sd'|' -)"
expect "opencode: reviewer keeps opus" "model: anthropic/claude-opus-5-5" "$(grep '^model:' "$oc/agents/harness-reviewer.md")"
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
