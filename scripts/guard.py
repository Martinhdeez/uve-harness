#!/usr/bin/env python3
"""PreToolUse guard. Three rules, each decided by the machine and not by a prompt:

1. Secrets: no agent reads a .env file other than an example. Denied.
2. Gate: `gh pr create` needs a green gate stamp on the current commit. Denied.
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
    r"(?:^|[\s;&|(])(cat|bat|less|more|head|tail|grep|rg|sed|awk|cut|strings|xxd|base64|nl|tac)\s"
)


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


def check_bash(command, cwd):
    if READERS.search(command):
        for match in ENV_FILE.finditer(command):
            if is_secret(match.group(1)):
                decide("deny", f"{match.group(1)} is a secrets file; read .env.example instead.")

    out = run(["git", "branch", "--show-current"], cwd)
    on_protected = bool(out) and out.stdout.strip() in PROTECTED

    # ponytail: splits on shell operators without parsing quotes, so a commit message that
    # quotes one of these commands can trigger a prompt. Asking once too often is the safe side.
    for segment in re.split(r"&&|\|\||[;|\n]", command):
        tokens = segment.split()
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
        elif tokens[:3] == ["gh", "pr", "create"]:
            gate = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bin", "harness-gate")
            check = run([gate, "--check"], cwd)
            if check and check.returncode == 2:
                decide("deny", check.stderr.strip())


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
