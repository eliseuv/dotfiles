"""The API behind the dashboard's host pages (hosts.nix), part of svcctl,
which serves it at /api/hosts/. Read-only; the pages' switch button is
svcctl's own.
configure() takes svcctl's `pages` section: `hosts` maps host names to
{tile, hosts, user, switch, mdns, tailnet}. With `hosts` empty the host is
this one and `host_report` runs here; otherwise it runs there, through the
remote-control forced command (services/remote-control.nix), over svcctl's
SSH login, which tries each name in `hosts` until one connects. Reports are
cached in svcctl's state directory, so a page shows the last one while its
host is off. A host with `snmp` set can't run host-report (a Synology): only
its uptime is read, with snmpget, using the net-snmp client config at
$SVCCTL_SNMP_CONF. Each host's LAN address is looked up by its `mdns` name
(the router hands out no fixed ones) and, like reports, kept for when the host
is off; its `tailnet` address is static. Closure diffs are cached for good: a generation never changes.
`eval_file` is dotfiles-eval.service's evaluation of master (hosts.nix).
Importing this starts nothing; svcctl calls configure() and start()."""

import json
import os
import re
import socket
import subprocess
import threading
import tempfile
import time
import weakref
from pathlib import Path
from urllib.parse import unquote, urlsplit

# Each refresh of a remote host is an SSH login, so: every few minutes in the
# background, sooner when a page asks, but no more often than this.
REFRESH_INTERVAL = 300
MIN_REFRESH_GAP = 30
# diff-closures over a large change takes a while.
REPORT_TIMEOUT = 60

# All set by configure(); empty, the API knows no hosts.
hosts = {}
eval_file = None
state_dir = reports_dir = diffs_dir = snmp_dir = None
host_report = None
# svcctl's remote_any(), None without an SSH key.
run_remote = None
# Host -> its last resolved LAN address.
lan_addresses = {}
# Host -> {report, fetched_at, attempted_at, error, refreshing, boot_at}.
state = {}
pokes = {}

# The refreshers share one file (and its temp file).
lan_addresses_lock = threading.Lock()

# Serialize requests for each host/pair so concurrent clients share the cache.
comparison_lock = threading.Lock()
comparison_locks = weakref.WeakValueDictionary()


def configure(pages, state_directory, runtime_directory, remote, snmp_conf):
    global hosts, eval_file, state_dir, reports_dir, diffs_dir, snmp_dir
    global host_report, run_remote, lan_addresses, state, pokes
    hosts = pages["hosts"]
    eval_file = Path(pages["eval_file"])
    host_report = pages["host_report"]
    run_remote = remote
    state_dir = state_directory
    reports_dir = state_dir / "reports"
    diffs_dir = state_dir / "diffs"
    reports_dir.mkdir(exist_ok=True)
    diffs_dir.mkdir(exist_ok=True)
    # net-snmp finds its credentials as snmp.conf in SNMPCONFPATH, a
    # directory, and wants a place to keep its engine state.
    snmp_dir = runtime_directory / "snmp"
    if snmp_conf:
        snmp_dir.mkdir(exist_ok=True)
        (snmp_dir / "snmp.conf").unlink(missing_ok=True)
        (snmp_dir / "snmp.conf").symlink_to(snmp_conf)
    lan_addresses = load_addresses()
    state = {
        host: {
            **load_cached(host),
            "attempted_at": None,
            "error": None,
            "refreshing": False,
            # When the host booted, by this clock. Not cached on disk: the
            # host may have rebooted since, and the tiles count uptime from it.
            "boot_at": None,
        }
        for host in hosts
    }
    pokes = {host: threading.Event() for host in hosts}


def start(spawn):
    # `spawn` is svcctl's, which restarts a refresher an error ended.
    for host in hosts:
        spawn(refresher, host)


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
    # Adjacent and arbitrary comparisons can produce the same cache entry.
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as file:
        tmp = Path(file.name)
        try:
            json.dump(data, file)
            file.close()
            tmp.replace(path)
        finally:
            tmp.unlink(missing_ok=True)


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
                [host_report, *args], capture_output=True, text=True, timeout=REPORT_TIMEOUT
            )
        elif run_remote is None:
            raise RuntimeError("no SSH key")
        else:
            result = run_remote(
                target["hosts"], " ".join(args), target["user"], timeout=REPORT_TIMEOUT
            )
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
    with lan_addresses_lock:
        if lan_addresses.get(host) != found:
            lan_addresses[host] = found
            write_atomically(state_dir / "addresses.json", lan_addresses)


def refresh(host):
    resolve_lan_address(host)
    entry = state[host]
    entry["refreshing"] = True
    entry["attempted_at"] = time.time()
    # Cleared whatever happens, or the page polls for a refresh that never
    # lands.
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
    finally:
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


def request_lock(key):
    with comparison_lock:
        return comparison_locks.setdefault(key, threading.Lock())


def diff(host, number):
    # The cached diff for generation `number` against the one before it, as
    # the last report has them; otherwise asks the host, which knows best.
    with request_lock((host, "diff", number)):
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


def compare(host, base, number):
    with request_lock((host, base, number)):
        report = state[host]["report"]
        kept = {g["number"]: g for g in (report or {}).get("generations", [])}
        if base not in kept or number not in kept:
            raise RuntimeError("Generation unavailable; refresh the host report")
        cached = diff_file(kept[number]["path"], kept[base]["path"])
        if cached.exists():
            return {**json.loads(cached.read_text()), "base": base, "number": number}
        result = run_report(host, "compare", str(base), str(number))
        write_atomically(diff_file(result["path"], result["base_path"]), result)
        return result


def get(path):
    """(status, body) for a GET of `path` under /api/hosts/."""
    url = urlsplit(path)
    parts = [unquote(part) for part in url.path.strip("/").split("/")]
    if len(parts) < 3 or parts[:2] != ["api", "hosts"] or parts[2] not in hosts:
        return 404, None
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
        return (
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
    if (len(parts) == 6 and parts[3] == "compare"
            and all(re.fullmatch(r"[0-9]+", part) for part in parts[4:])):
        try:
            return 200, compare(host, int(parts[4]), int(parts[5]))
        except RuntimeError as error:
            return 502, {"error": str(error)}
    if len(parts) == 5 and parts[3] == "diff" and re.fullmatch(r"[0-9]+", parts[4]):
        try:
            return 200, diff(host, int(parts[4]))
        except RuntimeError as error:
            return 502, {"error": str(error)}
    return 404, None
