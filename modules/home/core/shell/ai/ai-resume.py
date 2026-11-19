"""Fuzzy-pick a Claude Code or Codex session and continue it.

Sources:
  - Claude transcripts under ~/.claude/projects/*/*.jsonl; a transcript
    whose first entrypoint is `sdk-cli` was spawned by `claude remote-control`
  - Running Claude sessions from `claude agents --json`; a process in the
    claude-remote-control.service cgroup is a Remote Control (app) session
  - Codex threads from `codex app-server` (stdio JSON-RPC `thread/list`);
    an originator ending in `_remote` marks a thread started from the app

None of these formats is a stable API, so every parser tolerates missing
fields and a failing source only costs its own rows.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

CLAUDE_REMOTE_UNIT = "claude-remote-control.service"
CODEX_REMOTE_SOCKET = (
    Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    / "codex-remote-control/app-server.sock"
)
CODEX_SOURCE_KINDS = ["cli", "vscode", "appServer"]

ANSI = {
    "claude": "\033[38;5;173m",
    "codex": "\033[38;5;75m",
    "remote": "\033[1;35m",
    "live": "\033[1;32m",
    "bg": "\033[1;33m",
    "dim": "\033[2m",
    "reset": "\033[0m",
}


def warn(message):
    print(f"ai-resume: {message}", file=sys.stderr)


def one_line(text, limit=200):
    return " ".join((text or "").split())[:limit]


# Claude --------------------------------------------------------------------


def read_claude_transcript(path):
    """Extract id, cwd and the best available title from one transcript.

    Only lines that can carry a wanted field are JSON-decoded; transcripts
    are dominated by large assistant/tool records.
    """
    cwd = None
    entrypoint = None
    first_prompt = None
    titles = {}
    wanted = ('"custom-title"', '"ai-title"', '"agent-name"', '"last-prompt"')
    try:
        with open(path, encoding="utf-8", errors="replace") as transcript:
            for line in transcript:
                needs_cwd = cwd is None and '"cwd":"' in line
                needs_entrypoint = entrypoint is None and '"entrypoint":"' in line
                needs_prompt = first_prompt is None and '"type":"user"' in line
                if not (needs_cwd or needs_entrypoint or needs_prompt) and not any(
                    marker in line for marker in wanted
                ):
                    continue
                try:
                    record = json.loads(line)
                except ValueError:
                    continue
                if needs_cwd and record.get("cwd"):
                    cwd = record["cwd"]
                if needs_entrypoint and record.get("entrypoint"):
                    entrypoint = record["entrypoint"]
                if needs_prompt and record.get("type") == "user":
                    first_prompt = user_text(record) or None
                for field in ("customTitle", "aiTitle", "agentName", "lastPrompt"):
                    if record.get(field):
                        titles[field] = record[field]
    except OSError:
        return None
    title = next(
        (titles[f] for f in ("customTitle", "aiTitle", "agentName", "lastPrompt") if f in titles),
        first_prompt,
    )
    if not title:
        # Nothing was ever asked; `claude --resume` hides these too
        return None
    return {
        "tool": "claude",
        "id": path.stem,
        "cwd": cwd or "",
        "title": one_line(title),
        "time": path.stat().st_mtime,
        "flags": {"remote"} if entrypoint == "sdk-cli" else set(),
        "detail": one_line(titles.get("lastPrompt") or first_prompt, 1000),
        "source": entrypoint or "",
    }


def user_text(record):
    """First prompt text of a user record, skipping tool results and the
    `<command-...>`/`<system-reminder>` wrappers the harness injects."""
    content = (record.get("message") or {}).get("content")
    if isinstance(content, list):
        content = next(
            (block.get("text") for block in content
             if isinstance(block, dict) and block.get("type") == "text"),
            None,
        )
    if not isinstance(content, str) or content.lstrip().startswith("<"):
        return ""
    return content


def claude_transcripts():
    root = Path.home() / ".claude/projects"
    sessions = {}
    for path in root.glob("*/*.jsonl"):
        session = read_claude_transcript(path)
        if session:
            sessions[session["id"]] = session
    return sessions


def in_remote_cgroup(pid):
    try:
        return CLAUDE_REMOTE_UNIT in Path(f"/proc/{pid}/cgroup").read_text()
    except OSError:
        return False


def claude_running():
    if not shutil.which("claude"):
        return []
    try:
        output = subprocess.run(
            ["claude", "agents", "--json"],
            capture_output=True, text=True, timeout=20, check=True,
        ).stdout
        return json.loads(output)
    except (OSError, subprocess.SubprocessError, ValueError) as error:
        warn(f"claude agents --json failed: {error}")
        return []


def claude_sessions():
    sessions = claude_transcripts()
    for agent in claude_running():
        session_id = agent.get("sessionId")
        if not session_id:
            continue
        session = sessions.setdefault(session_id, {
            "tool": "claude", "id": session_id, "cwd": agent.get("cwd", ""),
            "title": agent.get("name", ""), "time": 0, "flags": set(), "detail": "",
        })
        session["cwd"] = agent.get("cwd") or session["cwd"]
        session["time"] = max(session["time"], (agent.get("startedAt") or 0) / 1000)
        if in_remote_cgroup(agent.get("pid")):
            session["flags"].add("remote")
        if agent.get("kind") == "background":
            session["flags"].add("bg")
            # `claude attach` takes the agent-view name, not the session id
            session["attach"] = agent.get("name") or session_id
        else:
            session["flags"].add("live")
        if agent.get("name"):
            session["name"] = agent["name"]
    return list(sessions.values())


# Codex ---------------------------------------------------------------------


class AppServer:
    """Minimal newline-delimited JSON-RPC client for `codex app-server`."""

    def __init__(self):
        self.process = subprocess.Popen(
            ["codex", "app-server"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            text=True,
        )
        self.next_id = 0

    def notify(self, method, params=None):
        message = {"method": method}
        if params is not None:
            message["params"] = params
        self.process.stdin.write(json.dumps(message) + "\n")
        self.process.stdin.flush()

    def request(self, method, params):
        self.next_id += 1
        self.process.stdin.write(
            json.dumps({"id": self.next_id, "method": method, "params": params}) + "\n"
        )
        self.process.stdin.flush()
        for line in self.process.stdout:
            try:
                message = json.loads(line)
            except ValueError:
                continue
            if message.get("id") != self.next_id:
                continue
            if "error" in message:
                raise RuntimeError(message["error"].get("message", "unknown error"))
            return message["result"]
        raise RuntimeError("app-server exited")

    def close(self):
        try:
            self.process.stdin.close()
        except OSError:
            pass
        self.process.terminate()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()


def codex_threads():
    if not shutil.which("codex"):
        return []
    server = None
    threads = []
    try:
        server = AppServer()
        server.request("initialize", {
            "clientInfo": {"name": "ai_resume", "version": "1.0"},
            "capabilities": {"experimentalApi": True},
        })
        server.notify("initialized")
        cursor = None
        while True:
            page = server.request("thread/list", {
                "archived": False, "limit": 200, "cursor": cursor,
                "sourceKinds": CODEX_SOURCE_KINDS,
            })
            threads.extend(page.get("data") or [])
            cursor = page.get("nextCursor")
            if not cursor:
                break
    except (OSError, RuntimeError) as error:
        warn(f"codex thread/list failed: {error}")
    finally:
        if server:
            server.close()

    sessions = []
    for thread in threads:
        preview = thread.get("preview") or ""
        if not preview or thread.get("threadSource") == "guardian_review":
            continue
        originator = thread.get("originator") or ""
        sessions.append({
            "tool": "codex",
            "id": thread["id"],
            "cwd": thread.get("cwd") or "",
            "title": one_line(thread.get("name") or preview),
            "time": thread.get("recencyAt") or thread.get("updatedAt") or 0,
            "flags": {"remote"} if originator.endswith("_remote") else set(),
            "detail": one_line(preview, 1000),
            "originator": originator,
        })
    return sessions


# Picker --------------------------------------------------------------------


def age(timestamp):
    seconds = max(0, time.time() - timestamp)
    for unit, size in (("d", 86400), ("h", 3600), ("m", 60)):
        if seconds >= size:
            return f"{int(seconds // size)}{unit}"
    return "now"


def short_path(path):
    home = str(Path.home())
    return "~" + path[len(home):] if path == home or path.startswith(home + "/") else path


def display(session):
    tool = session["tool"]
    tags = "".join(
        f"{ANSI[flag]}{flag}{ANSI['reset']} " for flag in ("remote", "live", "bg")
        if flag in session["flags"]
    )
    return (
        f"{ANSI[tool]}{tool:<6}{ANSI['reset']} {ANSI['dim']}{age(session['time']):>4}{ANSI['reset']} "
        f"{tags}{ANSI['dim']}{short_path(session['cwd'])}{ANSI['reset']}  {session['title']}"
    )


def list_rows(cwd_only):
    here = os.getcwd()
    sessions = claude_sessions() + codex_threads()
    if cwd_only:
        sessions = [s for s in sessions if s["cwd"] == here]
    sessions.sort(key=lambda s: (s["cwd"] != here, -s["time"]))
    for session in sessions:
        source = session.get("originator") or session.get("name") or session.get("source") or ""
        fields = [
            session["tool"], session["id"], session["cwd"],
            ",".join(sorted(session["flags"])), session.get("attach", ""),
            display(session), session["detail"] or session["title"], source,
        ]
        print("\t".join(field.replace("\t", " ") for field in fields))


def resume_command(tool, session_id, cwd, flags, attach):
    if tool == "claude":
        if "bg" in flags:
            return ["claude", "attach", attach or session_id]
        return ["claude", "--resume", session_id]
    if "remote" in flags and CODEX_REMOTE_SOCKET.is_socket():
        # Hand the thread back to the service that owns it, like `codex-phone`
        return ["codex", "--remote", f"unix://{CODEX_REMOTE_SOCKET}", "resume", session_id]
    return ["codex", "resume", session_id, "-C", cwd]


def pick(args):
    self_command = f"{sys.executable} -I {os.path.abspath(__file__)} --list"
    query = " ".join(args.query)
    result = subprocess.run(
        [
            "fzf", "--ansi", "--delimiter", "\t", "--with-nth", "6",
            "--no-sort", "--query", query,
            "--prompt", "resume> ",
            "--header", "ctrl-d: this dir · ctrl-a: all dirs",
            "--bind", f"start:reload:{self_command}",
            "--bind", f"ctrl-d:reload:{self_command} --cwd-only",
            "--bind", f"ctrl-a:reload:{self_command}",
            "--preview", "printf '%s %s\\n%s\\n%s %s\\n\\n%s\\n' {1} {4} {2} {3} {8} {7}",
            "--preview-window", "down,8,wrap",
        ],
        stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, text=True, check=False,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return result.returncode or 1
    tool, session_id, cwd, flags, attach = result.stdout.rstrip("\n").split("\t")[:5]
    flags = set(filter(None, flags.split(",")))
    command = resume_command(tool, session_id, cwd, flags, attach)
    if args.print:
        print(f"cd {cwd} && {' '.join(command)}")
        return 0
    if cwd:
        if not os.path.isdir(cwd):
            warn(f"session directory no longer exists: {cwd}")
            return 1
        os.chdir(cwd)
    os.execvp(command[0], command)


def main():
    parser = argparse.ArgumentParser(description="Resume a Claude Code or Codex session.")
    parser.add_argument("query", nargs="*", help="Initial fzf query")
    parser.add_argument("--print", action="store_true", help="Print the command instead of running it")
    parser.add_argument("--list", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--cwd-only", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.list:
        list_rows(args.cwd_only)
        return 0
    return pick(args)


if __name__ == "__main__":
    sys.exit(main())
