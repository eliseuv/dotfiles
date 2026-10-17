"""hostctl PORT HOSTS_JSON EVAL_JSON STATE_DIR HOST_REPORT [SSH_KEY]: the API
behind the dashboard's host pages (hosts.nix). Read-only; the pages' switch
button goes to svcctl.
HOSTS_JSON maps host names to {tile, hosts, user, switch, mdns, tailnet}. With `hosts` empty
the host is this one and HOST_REPORT runs here; otherwise it runs there,
through the remote-control forced command (services/remote-control.nix),
logged in with SSH_KEY, trying each name in `hosts` until one connects.
Reports are cached in STATE_DIR, so a page shows the last one while its host
is off. A host with `snmp` set can't run HOST_REPORT (a Synology): only its
uptime is read, with snmpget, using the net-snmp client config at
$HOSTCTL_SNMP_CONF. Each host's LAN address is looked up by its `mdns` name
(the router hands out no fixed ones) and, like reports, kept for when the host
is off; its `tailnet` address is static. Closure diffs are cached for good: a generation never changes.
EVAL_JSON is dotfiles-eval.service's evaluation of master (hosts.nix)."""

import json
import os
import re
import socket
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

port = int(sys.argv[1])
with open(sys.argv[2]) as file:
    hosts = json.load(file)
eval_file = Path(sys.argv[3])
state_dir = Path(sys.argv[4])
host_report = sys.argv[5]
ssh_key = sys.argv[6] if len(sys.argv) > 6 else None

# Each refresh of a remote host is an SSH login, so: every few minutes in the
# background, sooner when a page asks, but no more often than this.
REFRESH_INTERVAL = 300
MIN_REFRESH_GAP = 30

# net-snmp finds its credentials as snmp.conf in SNMPCONFPATH, a directory,
# and wants a place to keep its engine state.
snmp_dir = Path(os.environ.get("RUNTIME_DIRECTORY", state_dir)) / "snmp"
if os.environ.get("HOSTCTL_SNMP_CONF"):
    snmp_dir.mkdir(exist_ok=True)
    (snmp_dir / "snmp.conf").unlink(missing_ok=True)
    (snmp_dir / "snmp.conf").symlink_to(os.environ["HOSTCTL_SNMP_CONF"])

reports_dir = state_dir / "reports"
diffs_dir = state_dir / "diffs"
reports_dir.mkdir(exist_ok=True)
diffs_dir.mkdir(exist_ok=True)


def load_cached(host):
    try:
        return json.loads((reports_dir / f"{host}.json").read_text())
    except (OSError, ValueError):
        return {"report": None, "fetched_at": None}


def load_addresses():
    try:
        return json.loads((state_dir / "addresses.json").read_text())
    except (OSError, ValueError):
        return {}


def write_atomically(path, data):
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data))
    tmp.replace(path)


# Host -> its last resolved LAN address.
lan_addresses = load_addresses()


# Host -> {report, fetched_at, attempted_at, error, refreshing}.
state = {
    host: {
        **load_cached(host),
        "attempted_at": None,
        "error": None,
        "refreshing": False,
        # When the host booted, by this clock. Not cached on disk: the host
        # may have rebooted since, and the tiles count uptime from it.
        "boot_at": None,
    }
    for host in hosts
}
pokes = {host: threading.Event() for host in hosts}


def remote(host, verb, user):
    # Same login as svcctl's remote() (svcctl.py), which explains the options.
    return subprocess.run(
        [
            "ssh",
            "-F", "/dev/null",
            "-i", ssh_key,
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=5",
            "-o", "StrictHostKeyChecking=yes",
            "-o", "UserKnownHostsFile=/dev/null",
            f"{user}@{host}",
            verb,
        ],
        capture_output=True,
        text=True,
        # diff-closures over a large change takes a while.
        timeout=60,
    )


def snmp_uptime(host):
    # hrSystemUpTime.0, in hundredths of a second; -Ot prints it as that
    # number. Not sysUpTime.0, which is the SNMP agent's: it restarts with
    # the service, e.g. when SNMP settings are applied.
    result = subprocess.run(
        [
            "snmpget", "-m", "", "-t", "3", "-r", "1", "-Oqvt",
            hosts[host]["hosts"][0], "1.3.6.1.2.1.25.1.1.0",
        ],
        capture_output=True,
        text=True,
        timeout=30,
        env={**os.environ, "SNMPCONFPATH": str(snmp_dir), "SNMP_PERSISTENT_DIR": str(snmp_dir)},
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"exit {result.returncode}")
    try:
        return {"uptime": int(result.stdout.strip()) // 100}
    except ValueError:
        raise RuntimeError("unreadable uptime")


def run_report(host, *args):
    # host-report's output, raising RuntimeError with the reason it failed.
    target = hosts[host]
    try:
        if not target["hosts"]:
            result = subprocess.run(
                [host_report, *args], capture_output=True, text=True, timeout=60
            )
        else:
            if not ssh_key:
                raise RuntimeError("no SSH key")
            # ssh exits 255 when it can't connect (or log in); anything else is
            # the forced command's own exit, so only that moves on.
            for name in target["hosts"]:
                result = remote(name, " ".join(args), target["user"])
                if result.returncode != 255:
                    break
    except subprocess.TimeoutExpired:
        raise RuntimeError("timed out")
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"exit {result.returncode}")
    try:
        return json.loads(result.stdout)
    except ValueError:
        raise RuntimeError("unreadable report")


def resolve_lan_address(host):
    try:
        found = socket.getaddrinfo(hosts[host]["mdns"], None, socket.AF_INET)[0][4][0]
    except (OSError, KeyError):
        return
    if lan_addresses.get(host) != found:
        lan_addresses[host] = found
        write_atomically(state_dir / "addresses.json", lan_addresses)


def refresh(host):
    resolve_lan_address(host)
    entry = state[host]
    entry["refreshing"] = True
    entry["attempted_at"] = time.time()
    try:
        report = snmp_uptime(host) if hosts[host].get("snmp") else run_report(host, "generations")
    except RuntimeError as error:
        entry["error"] = str(error)
    else:
        entry.update(report=report, fetched_at=time.time(), error=None)
        if "uptime" in report:
            entry["boot_at"] = entry["fetched_at"] - report["uptime"]
        write_atomically(
            reports_dir / f"{host}.json",
            {"report": report, "fetched_at": entry["fetched_at"]},
        )
    entry["refreshing"] = False


def refresher(host):
    while True:
        refresh(host)
        pokes[host].wait(REFRESH_INTERVAL)
        pokes[host].clear()


def load_master(host):
    try:
        evaluation = json.loads(eval_file.read_text())
    except (OSError, ValueError):
        return None
    return {
        "rev": evaluation.get("rev"),
        "checked_at": evaluation.get("checked_at"),
        "evaluated_at": evaluation.get("evaluated_at"),
        **evaluation.get("hosts", {}).get(host, {"error": "not evaluated yet"}),
    }


def deploy_status(report, master):
    # "current": runs what master builds. "pending": master's system is the
    # newest generation but not running (a boot switch, or a failed
    # activation). "differs": anything else, behind or ahead alike, which
    # only the commits can tell apart.
    if not report or not master or "path" not in master:
        return {"state": "unknown", "generation": None}
    path = master["path"]
    generations = report["generations"]
    number = next((g["number"] for g in generations if g["path"] == path), None)
    if report["current"] == path:
        status = "current"
    elif number is not None and number == max(g["number"] for g in generations):
        status = "pending"
    else:
        status = "differs"
    return {"state": status, "generation": number}


def store_hash(path):
    return Path(path).name.split("-", 1)[0] if path else "none"


def diff_file(path, base_path):
    return diffs_dir / f"{store_hash(base_path)}-{store_hash(path)}.json"


def diff(host, number):
    # The cached diff for generation `number` against the one before it, as
    # the last report has them; otherwise asks the host, which knows best.
    report = state[host]["report"]
    if report:
        numbers = [g["number"] for g in report["generations"]]
        if number in numbers:
            index = numbers.index(number)
            path = report["generations"][index]["path"]
            base_path = report["generations"][index - 1]["path"] if index else None
            cached = diff_file(path, base_path)
            if cached.exists():
                return json.loads(cached.read_text())
    result = run_report(host, "diff", str(number))
    write_atomically(diff_file(result["path"], result["base_path"]), result)
    return result


class Handler(BaseHTTPRequestHandler):
    def reply(self, status, body=None):
        data = json.dumps(body).encode() if body is not None else b""
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        url = urlsplit(self.path)
        parts = [unquote(part) for part in url.path.strip("/").split("/")]
        if len(parts) < 3 or parts[:2] != ["api", "hosts"] or parts[2] not in hosts:
            return self.reply(404)
        host = parts[2]
        if len(parts) == 3:
            entry = state[host]
            if "refresh=1" in url.query.split("&") and not entry["refreshing"]:
                if time.time() - (entry["attempted_at"] or 0) >= MIN_REFRESH_GAP:
                    # Set here too, so the page polls until the refresh lands.
                    entry["refreshing"] = True
                    pokes[host].set()
            master = load_master(host)
            now = time.time()
            # Seconds since the host booted as of now, and how old the fetch
            # behind it is; relative, so the tiles needn't share this clock.
            booted = entry["boot_at"] is not None
            return self.reply(
                200,
                {
                    "host": host,
                    "tile": hosts[host]["tile"],
                    "switch": hosts[host]["switch"],
                    **entry,
                    "uptime": now - entry["boot_at"] if booted else None,
                    "uptime_age": now - entry["fetched_at"] if booted else None,
                    "addresses": {
                        "lan": lan_addresses.get(host),
                        "tailnet": hosts[host].get("tailnet"),
                    },
                    "master": master,
                    "status": deploy_status(entry["report"], master),
                },
            )
        if len(parts) == 5 and parts[3] == "diff" and re.fullmatch(r"[0-9]+", parts[4]):
            try:
                return self.reply(200, diff(host, int(parts[4])))
            except RuntimeError as error:
                return self.reply(502, {"error": str(error)})
        self.reply(404)

    def log_message(self, format, *args):
        sys.stderr.write("%s\n" % (format % args))


for host in hosts:
    threading.Thread(target=refresher, args=(host,), daemon=True).start()
ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
