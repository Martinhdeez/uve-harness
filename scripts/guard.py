#!/usr/bin/env python3
"""PreToolUse guard. Three rules, each decided by the machine and not by a prompt:

1. Secrets: no agent reads a .env file other than an example. Denied.
2. Gate and scope: in a project with a `## Harness` section, `gh pr create` needs a green gate
   stamp on the current commit, and every changed file inside `.scratch/scope` when the
   worktree has one. Denied.
3. main: a push or a merge that lands on main or master asks the user. Never automatic.
"""
import json
import os
import re
import subprocess
import sys

PROTECTED = {"main", "master"}
ENV_FILE = re.compile(r"(?:^|[\s/'\"=<])(\.env(?:\.[\w-]+)?)(?=$|[\s'\";|&)>])")
EXAMPLES = (".example", ".sample", ".template", ".dist")
READERS = re.compile(
    r"(?:^|[\s;&|(])(cat|bat|less|more|head|tail|grep|rg|sed|awk|cut|strings|xxd|base64|nl|tac"
    r"|od|hexdump|diff|sort|uniq|jq|yq|source|vim?|nvim|nano|emacs|view"
    r"|python3?|node|deno|bun|ruby|perl|php)\s"
)
# `. .env` sources it and `< .env` feeds it to any command; neither needs a reader name.
DOT_OR_REDIRECT = re.compile(r"(?:(?:^|[;&|(]\s*)\.\s+|<\s*)['\"]?([^\s'\";|&)<>]+)")
# Loading an env file into a process is how apps run; it does not print the secrets.
ENV_FILE_FLAG = re.compile(r"--env-file[=\s]+\S+")


def is_secret(name):
    name = os.path.basename(name)
    return (name == ".env" or name.startswith(".env.")) and not name.endswith(EXAMPLES)


def decide(decision, reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": "harness: " + reason,
    }}))
    sys.exit(0)


def run(args, cwd):
    try:
        return subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        return None


def targets_protected(tokens):
    for token in tokens:
        ref = token.strip("'\"+").split(":")[-1]
        if ref.removeprefix("refs/heads/") in PROTECTED:
            return True
    return False


def opted_in(cwd):
    """The gate is required only in a project prepared with /harness:init."""
    top = run(["git", "rev-parse", "--show-toplevel"], cwd)
    if not top or top.returncode != 0:
        return False
    for name in ("AGENTS.md", "CLAUDE.md"):
        try:
            with open(os.path.join(top.stdout.strip(), name), encoding="utf-8") as f:
                if re.search(r"^## Harness\s*$", f.read(), re.M):
                    return True
        except OSError:
            pass
    return False


def check_bash(command, cwd):
    # ponytail: a name-based list, not a sandbox. `cp .env x` and then reading x still gets
    # through; real isolation needs the secrets outside the agent's filesystem.
    scan = ENV_FILE_FLAG.sub(" ", command)
    if READERS.search(scan):
        for match in ENV_FILE.finditer(scan):
            if is_secret(match.group(1)):
                decide("deny", f"{match.group(1)} is a secrets file; read .env.example instead.")
    for match in DOT_OR_REDIRECT.finditer(scan):
        if is_secret(match.group(1)):
            decide("deny", f"{os.path.basename(match.group(1))} is a secrets file; read .env.example instead.")

    out = run(["git", "branch", "--show-current"], cwd)
    on_protected = bool(out) and out.stdout.strip() in PROTECTED

    # ponytail: splits on shell operators without parsing quotes, so a commit message that
    # quotes one of these commands can trigger a prompt. Asking once too often is the safe side.
    for segment in re.split(r"&&|\|\||[;|\n]", command):
        tokens = segment.split()
        if tokens[:1] == ["cd"] and len(tokens) == 2:
            # Later segments run in that directory: check the stamp and branch there.
            cwd = os.path.join(cwd, os.path.expanduser(tokens[1].strip("'\"")))
            out = run(["git", "branch", "--show-current"], cwd)
            on_protected = bool(out) and out.stdout.strip() in PROTECTED
            continue
        if "git" in tokens and "push" in tokens:
            args = [t for t in tokens[tokens.index("push") + 1:] if not t.startswith("-")]
            if targets_protected(args) or (on_protected and len(args) < 2):
                decide("ask", "this pushes to main. Only the user sends work to main.")
        elif "git" in tokens and "merge" in tokens and on_protected and "--abort" not in tokens:
            decide("ask", "this merges into main. Only the user merges into main.")
        elif tokens[:3] == ["gh", "pr", "merge"]:
            number = next((t for t in tokens[3:] if not t.startswith("-")), None)
            view = ["gh", "pr", "view"] + ([number] if number else [])
            base = run(view + ["--json", "baseRefName", "-q", ".baseRefName"], cwd)
            if not base or base.returncode != 0:
                decide("ask", "could not read the base branch of this pull request.")
            if base.stdout.strip() in PROTECTED:
                decide("ask", "this pull request merges into main. Only the user merges into main.")
        elif tokens[:3] == ["gh", "pr", "create"] and opted_in(cwd):
            bin_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bin")
            check = run([os.path.join(bin_dir, "harness-gate"), "--check"], cwd)
            if check and check.returncode == 2:
                decide("deny", check.stderr.strip())
            base = next((tokens[i + 1] for i, t in enumerate(tokens[:-1]) if t in ("--base", "-B")), "dev")
            scope = run([os.path.join(bin_dir, "harness-scope"), base], cwd)
            if scope and scope.returncode == 1:
                decide("deny", "the branch changes files outside the brief's scope (.scratch/scope):\n"
                       + scope.stdout.strip() + "\nRevert them, or report that the brief must widen.")


def main():
    try:
        event = json.load(sys.stdin)
    except ValueError:
        return
    tool = event.get("tool_name")
    tool_input = event.get("tool_input") or {}
    if tool == "Bash":
        check_bash(tool_input.get("command", ""), event.get("cwd") or os.getcwd())
    elif tool in ("Read", "Grep"):
        path = tool_input.get("file_path") or tool_input.get("path") or ""
        if is_secret(path):
            decide("deny", f"{os.path.basename(path)} is a secrets file; read .env.example instead.")


main()
