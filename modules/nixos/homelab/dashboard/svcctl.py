"""svcctl PORT UNITS_JSON WAKE_JSON REBOOT_JSON SWITCH_JSON TAILSCALE_JSON PORTS_JSON MENU_JSON [SSH_KEY]:
start/stop/restart a fixed set of systemd units for the dashboard's tile
buttons (controls.nix).
UNITS_JSON maps tile names to {unit, hosts, user}; nothing else can be
touched. With `hosts` empty the unit is here, and polkit enforces the same
list; otherwise it's on another host, driven through the SSH login below,
whose forced command enforces its own list. WAKE_JSON maps tile names to {mac, host, poweroff} for
tiles that wake another machine: Wake-on-LAN instead of a unit, and up/down
from pinging `host`. Those with `poweroff` are powered off by an SSH login with
SSH_KEY, which the host pins to its remote-control forced command.
REBOOT_JSON and SWITCH_JSON map tile names to {hosts} for hosts that can be
rebooted, or whose dotfiles-switch.service can be started: here when `hosts`
is empty, otherwise through the same SSH login, trying each name in turn until
one connects. TAILSCALE_JSON likewise maps tiles to {hosts} whose Tailscale can
be turned on and off, always through that login. PORTS_JSON maps tiles to
{hosts, ports}: TCP ports reported open or closed, on this host when `hosts`
is empty. MENU_JSON, the host tiles' controls for the Homelab rofi menu, is
served as is.
Also serves per-service resource usage, read from the cgroup tree."""

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
from urllib.parse import unquote

port = int(sys.argv[1])
with open(sys.argv[2]) as file:
    units = json.load(file)
with open(sys.argv[3]) as file:
    wakeable = json.load(file)
with open(sys.argv[4]) as file:
    rebootable = json.load(file)
with open(sys.argv[5]) as file:
    switchable = json.load(file)
with open(sys.argv[6]) as file:
    tailscalable = json.load(file)
with open(sys.argv[7]) as file:
    port_targets = json.load(file)
with open(sys.argv[8]) as file:
    host_menu = json.load(file)
ssh_key = sys.argv[9] if len(sys.argv) > 9 else None

ACTIONS = {"start", "stop", "restart"}
SWITCH_UNIT = "dotfiles-switch.service"
# switch-status (services/_switch-status.nix), for this host's own switch.
SWITCH_STATUS = os.environ.get("SVCCTL_SWITCH_STATUS")
# A switch started from here that hasn't begun to run this long after is
# taken not to have started at all.
SWITCH_START_GRACE = 60


local_units = {name: target["unit"] for name, target in units.items() if not target["hosts"]}
remote_units = {name: target for name, target in units.items() if target["hosts"]}

# Tile name -> hosts to ping for up/down, up if any answers: wake tiles, and
# remote reboot, switch, tailscale and unit tiles that aren't also wake tiles.
probed = {name: [target["host"]] for name, target in wakeable.items()}
for targets in (rebootable, switchable, tailscalable, remote_units, port_targets):
    for name, target in targets.items():
        if target["hosts"] and name not in probed:
            probed[name] = target["hosts"]

# Tile name -> "up"/"down", kept fresh by probe() rather than pinged per
# request: a sleeping host's mDNS lookup alone takes ~9s to fail.
reachable = {name: "unknown" for name in probed}

# Tile name -> "idle"/"switching"/"failed" for remote switch tiles, and the
# status the host keeps of its latest run, from watch_switch(); the local one
# is read on each request.
remote_switch = {
    name: "unknown" for name, target in switchable.items() if target["hosts"]
}
remote_switch_detail = {name: None for name in remote_switch}

# Tile name -> {previous, modern, since} for switches started from here that
# haven't been seen to end: `previous` is the run before, so its result isn't
# taken for the new one's. See track_switch().
pending_switch = {}

# Remote switch tiles with a watch_switch() running; starting and ending one
# hold the lock, so a switch can't land between a watcher's last look and its
# end.
switch_watchers = set()
switch_watchers_lock = threading.Lock()


# Tile name -> "on"/"off"/"unknown" for Tailscale tiles, from watch_tailscale().
tailscale_state = {name: "unknown" for name in tailscalable}


# Tile name -> `systemctl is-active` output for remote unit tiles, from
# watch_unit(); its event wakes the watcher early after an action.
remote_unit_state = {name: "unknown" for name in remote_units}
remote_unit_poke = {name: threading.Event() for name in remote_units}


# Tile name -> round-trip time in ms of the last answered ping, None while down.
latency = {name: None for name in probed}


# Tile name -> {port: open?}, from watch_ports().
port_state = {
    name: {str(port): False for port in target["ports"]} for name, target in port_targets.items()
}


CGROUP_ROOT = Path("/sys/fs/cgroup")
USAGE_INTERVAL = 3

# Unit -> tile name, so services with a tile show up under its name.
tile_of_unit = {target["unit"]: name for name, target in units.items() if not target["hosts"]}

# Latest sample, replaced whole by sample_usage(); each entry is
# {unit, label, cpu, memory, tasks, read, write}.
usage = []


def read_int(path):
    try:
        return int(path.read_text())
    except (OSError, ValueError):
        return 0


def read_keyed(path):
    # "key value" lines (cpu.stat, memory.stat).
    try:
        return {
            key: int(value)
            for key, value in (line.split() for line in path.read_text().splitlines())
        }
    except (OSError, ValueError):
        return {}


def read_io(path):
    # io.stat has one line per device: sum read and written bytes over them.
    read = write = 0
    try:
        lines = path.read_text().splitlines()
    except OSError:
        return 0, 0
    for line in lines:
        fields = dict(field.split("=") for field in line.split()[1:])
        read += int(fields.get("rbytes", 0))
        write += int(fields.get("wbytes", 0))
    return read, write


def service_cgroups():
    # Service cgroups under system.slice, plus all login sessions as one row.
    # A service's counters already include its children, so don't descend
    # into it; slices (system-getty.slice, ...) only group services.
    found = {}
    pending = [CGROUP_ROOT / "system.slice"]
    while pending:
        try:
            entries = list(pending.pop().iterdir())
        except OSError:
            continue
        for entry in entries:
            if entry.name.endswith(".service"):
                found[entry.name] = entry
            elif entry.name.endswith(".slice") and entry.is_dir():
                pending.append(entry)
    found["user.slice"] = CGROUP_ROOT / "user.slice"
    return found


def measure(path):
    memory = read_keyed(path / "memory.stat")
    # Like `docker stats`: page cache that can be dropped isn't the
    # service's footprint, and for a media server it would dwarf the rest.
    resident = max(read_int(path / "memory.current") - memory.get("inactive_file", 0), 0)
    read, write = read_io(path / "io.stat")
    return {
        "cpu_usec": read_keyed(path / "cpu.stat").get("usage_usec", 0),
        "memory": resident,
        "tasks": read_int(path / "pids.current"),
        "read": read,
        "write": write,
    }


def sample_usage():
    global usage
    previous = {}
    last = time.monotonic()
    while True:
        time.sleep(USAGE_INTERVAL)
        now = time.monotonic()
        elapsed = now - last
        last = now
        current = {unit: measure(path) for unit, path in service_cgroups().items()}
        rows = []
        for unit, sample in current.items():
            before = previous.get(unit)
            # A unit new since the last sample has no rate yet.
            if before is not None:
                rows.append(
                    {
                        "unit": unit,
                        "label": tile_of_unit.get(unit),
                        # Percent of one core, as in top.
                        "cpu": max(sample["cpu_usec"] - before["cpu_usec"], 0) / (elapsed * 1e4),
                        "memory": sample["memory"],
                        "tasks": sample["tasks"],
                        "read": max(sample["read"] - before["read"], 0) / elapsed,
                        "write": max(sample["write"] - before["write"], 0) / elapsed,
                    }
                )
        previous = current
        usage = rows


def memory_total():
    with open("/proc/meminfo") as file:
        return int(file.readline().split()[1]) * 1024


def ping(host):
    # Round-trip time in ms, None if unanswered.
    try:
        result = subprocess.run(
            ["ping", "-c1", "-W1", host],
            capture_output=True,
            text=True,
            timeout=15,
        )
    except subprocess.TimeoutExpired:
        return None
    match = re.search(r"time=([\d.]+) ms", result.stdout)
    return float(match.group(1)) if result.returncode == 0 and match else None


def probe(name, hosts):
    while True:
        rtt = next((r for r in map(ping, hosts) if r is not None), None)
        latency[name] = rtt
        reachable[name] = "up" if rtt is not None else "down"
        time.sleep(5)


def port_open(host, port):
    try:
        socket.create_connection((host, port), timeout=1).close()
        return True
    except OSError:
        return False


def watch_ports(name, target):
    # Another host's ports only while it answers pings, so a sleeping one
    # isn't asked for each port in turn; and only by its first name, the
    # tailnet one: its firewall drops the rest from the mDNS name, so trying
    # that too when nothing's open costs a timeout per port.
    host = target["hosts"][0] if target["hosts"] else "127.0.0.1"
    while True:
        state = {str(port): False for port in target["ports"]}
        if not target["hosts"] or reachable.get(name) == "up":
            state = {str(port): port_open(host, port) for port in target["ports"]}
        port_state[name] = state
        time.sleep(5)


def send_magic_packet(mac):
    payload = b"\xff" * 6 + bytes.fromhex(mac.replace(":", "")) * 16
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(payload, ("255.255.255.255", 9))


def remote(host, verb, user="remote-control"):
    # The host's authorized_keys forces its remote-control command, which
    # only takes the verb from here. known_hosts comes from the system file
    # only; svcctl has no home to keep one in. -F /dev/null skips the system
    # ssh_config, whose gpg-agent `Match exec` runs through svcctl's nologin
    # shell and logs a refused login on every call; the system known_hosts
    # is ssh's default anyway.
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
        timeout=20,
    )


def remote_any(hosts, verb, user="remote-control"):
    # ssh exits 255 when it can't connect (or log in), anything else is the
    # forced command's own exit; only the former moves on to the next name.
    # Raises the last TimeoutExpired if every name timed out.
    result = timeout = None
    for host in hosts:
        try:
            result = remote(host, verb, user)
        except subprocess.TimeoutExpired as error:
            timeout = error
            continue
        if result.returncode != 255:
            return result
    if result is None:
        raise timeout
    return result


def switch_state(show_output):
    # `systemctl show --property=ActiveState,Result --value`: two lines.
    lines = show_output.split()
    if len(lines) != 2:
        return "unknown"
    active, result = lines
    if active in ("activating", "active", "deactivating"):
        return "switching"
    if active == "failed" or result != "success":
        return "failed"
    return "idle"


def parse_switch(output):
    # (state, detail, run) from switch-status's JSON. A host not redeployed
    # since it gained switch-status still prints switch_state()'s two lines,
    # which tell neither the run nor its detail. `detail` is the status the
    # host keeps of the run, only once it's this run's.
    try:
        status = json.loads(output)
    except ValueError:
        return switch_state(output), None, None
    if not isinstance(status, dict) or "ActiveState" not in status:
        return "unknown", None, None
    last = status.get("last") if isinstance(status.get("last"), dict) else None
    # systemd unloads the unit once it's inactive, forgetting its
    # InvocationID and Result; the unit's own status still has them.
    run = status.get("InvocationID") or (last or {}).get("invocation")
    if last and last.get("invocation") != run:
        last = None
    if status["ActiveState"] in ("activating", "active", "deactivating"):
        state = "switching"
    elif status["ActiveState"] == "failed" or (last or {}).get("result") not in (None, "success"):
        state = "failed"
    else:
        state = "idle"
    return state, last, run


def begin_switch(name, before):
    # Called with what the host reported just before the start: switch-status
    # JSON, or nothing from a host that doesn't print it.
    previous = parse_switch(before)[2] if before.strip() else None
    pending_switch[name] = {
        "previous": previous,
        "modern": bool(before.strip()),
        "since": time.monotonic(),
    }


def track_switch(name, state, detail, run):
    # A switch started from here counts as switching until its run is seen:
    # `start --no-block` returns before the run begins, and until it does the
    # unit still shows the run before, idle or failed.
    pending = pending_switch.get(name)
    if pending is None:
        return state, detail
    if state == "switching" or (run is not None and run != pending["previous"]):
        pending["seen"] = True
    if state == "switching":
        return state, detail
    if pending.get("seen"):
        pending_switch.pop(name, None)
        return state, detail
    if time.monotonic() - pending["since"] < SWITCH_START_GRACE:
        return "switching", None
    pending_switch.pop(name, None)
    if not pending["modern"]:
        # No run to tell apart: a switch over between two polls looks like
        # one that never started.
        return state, detail
    return "failed", {"message": "the switch didn't start"}


def local_switch():
    if SWITCH_STATUS:
        command = [SWITCH_STATUS]
    else:
        command = ["systemctl", "show", "--property=ActiveState,Result", "--value", SWITCH_UNIT]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        return "unknown", None, None
    return parse_switch(result.stdout)


def watch_switch(name):
    # Polled over SSH only while a switch started from here hasn't been seen
    # to end, and from startup until the host first answers, rather than on
    # every status request: each poll is a login. Only while the host answers
    # pings, so one that's off costs nothing.
    target = switchable[name]
    while True:
        answered = False
        if reachable.get(name) == "up":
            try:
                result = remote_any(target["hosts"], "switch-status", target["user"])
                if result.returncode == 0:
                    answered = True
                    state, detail = track_switch(name, *parse_switch(result.stdout))
                    remote_switch[name] = state
                    remote_switch_detail[name] = detail
            except subprocess.TimeoutExpired:
                pass
        with switch_watchers_lock:
            if answered and remote_switch[name] != "switching" and name not in pending_switch:
                switch_watchers.discard(name)
                return
        time.sleep(10 if answered else 30)


def start_switch_watch(name):
    with switch_watchers_lock:
        if name in switch_watchers:
            return
        switch_watchers.add(name)
    threading.Thread(target=watch_switch, args=(name,), daemon=True).start()


def tailscale_backend(status_output):
    try:
        backend = json.loads(status_output)["BackendState"]
    except (ValueError, KeyError, TypeError):
        return "unknown"
    # Anything but Running (Stopped, NeedsLogin, ...) is off as far as the
    # button goes.
    return "on" if backend == "Running" else "off"


def watch_tailscale(name):
    # One login per poll, so only while the host answers pings; it can also be
    # toggled from its own desktop, which this is the only way to notice.
    while True:
        if reachable.get(name) == "up":
            try:
                result = remote_any(
                    tailscalable[name]["hosts"], "tailscale-status", tailscalable[name]["user"]
                )
                if result.returncode == 0:
                    tailscale_state[name] = tailscale_backend(result.stdout)
            except subprocess.TimeoutExpired:
                pass
        else:
            tailscale_state[name] = "unknown"
        time.sleep(30)


def watch_unit(name):
    # One login per poll, so only while the host answers pings: often while
    # the unit is changing state (Pluto takes minutes to start), rarely once
    # it's settled. It can also be started there by hand.
    target = remote_units[name]
    while True:
        if reachable.get(name) == "up":
            try:
                result = remote_any(target["hosts"], f"status {target['unit']}", target["user"])
                if result.returncode == 0 and result.stdout.strip():
                    remote_unit_state[name] = result.stdout.strip()
            except subprocess.TimeoutExpired:
                pass
        else:
            remote_unit_state[name] = "unknown"
        settling = remote_unit_state[name] in ("activating", "deactivating", "reloading")
        remote_unit_poke[name].wait(5 if settling else 30)
        remote_unit_poke[name].clear()


class Handler(BaseHTTPRequestHandler):
    def reply(self, status, body=None):
        # The access line only has the status; the cause is in the body.
        if status >= 500 and body and "error" in body:
            sys.stderr.write("%s\n" % body["error"])
        data = json.dumps(body).encode() if body is not None else b""
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def guarded(self):
        # Browsers only send a custom header cross-origin after a CORS
        # preflight, which this server never approves, so requiring it keeps
        # other websites from driving the API through a visitor's browser.
        if self.headers.get("X-Svcctl") != "1":
            self.reply(403, {"error": "missing X-Svcctl header"})
            return False
        return True

    def host_action(self, target, verb, local_command):
        # Runs `local_command` here when the target's `hosts` is empty, else
        # `verb` over SSH on the first of them that connects. Replies, and
        # returns the finished process if it worked, None otherwise.
        hosts = target["hosts"]
        if hosts and not ssh_key:
            self.reply(404)
            return None
        try:
            if hosts:
                result = remote_any(hosts, verb, target["user"])
            else:
                result = subprocess.run(local_command, capture_output=True, text=True)
        except subprocess.TimeoutExpired:
            self.reply(504, {"error": "ssh timed out"})
            return None
        if result.returncode != 0:
            self.reply(500, {"error": result.stderr.strip()})
            return None
        self.reply(202, {"ok": True})
        return result

    def do_GET(self):
        if not self.guarded():
            return
        prefix = "/api/svc/switch-log/"
        if self.path.startswith(prefix):
            name = unquote(self.path[len(prefix):])
            if name not in switchable:
                return self.reply(404)
            target = switchable[name]
            try:
                if target["hosts"]:
                    if not ssh_key:
                        return self.reply(503, {"error": "no SSH key"})
                    result = remote_any(target["hosts"], "switch-log", target["user"])
                else:
                    result = subprocess.run(
                        ["journalctl", "--quiet", "--no-pager", "--boot",
                         f"--unit={SWITCH_UNIT}", "--lines=300", "--output=short-iso"],
                        capture_output=True, timeout=15,
                    )
                if result.returncode:
                    error = result.stderr
                    if isinstance(error, bytes):
                        error = error.decode("utf-8", errors="replace")
                    return self.reply(502, {"error": error.strip() or "Switch output unavailable"})
                output = result.stdout
                if isinstance(output, str):
                    output = output.encode("utf-8")
                limit = 256 * 1024
                return self.reply(200, {
                    "output": output[-limit:].decode("utf-8", errors="replace"),
                    "fetched_at": time.time(), "truncated": len(output) > limit,
                })
            except subprocess.TimeoutExpired:
                return self.reply(504, {"error": "Switch output request timed out"})
        if self.path == "/api/svc/usage":
            return self.reply(
                200, {"cores": os.cpu_count(), "memory_total": memory_total(), "services": usage}
            )
        if self.path == "/api/svc/menu":
            return self.reply(200, host_menu)
        if self.path != "/api/svc/status":
            return self.reply(404)
        states = dict(reachable)
        # This host is up for as long as it's answering.
        states.update(
            (name, "up") for name, target in rebootable.items() if not target["hosts"]
        )
        switch = dict(remote_switch)
        switch_detail = dict(remote_switch_detail)
        local = [name for name, target in switchable.items() if not target["hosts"]]
        if local:
            reported = local_switch()
            for name in local:
                switch[name], switch_detail[name] = track_switch(name, *reported)
        if local_units:
            names = list(local_units)
            # One state per line, in argument order; non-zero exit when any
            # unit is inactive, which is not an error here.
            result = subprocess.run(
                ["systemctl", "is-active", *(local_units[name] for name in names)],
                capture_output=True,
                text=True,
            )
            states.update(zip(names, result.stdout.split()))
        # A remote unit's state while its host is up; "down" otherwise.
        states.update(
            (name, state)
            for name, state in remote_unit_state.items()
            if reachable.get(name) == "up"
        )
        self.reply(
            200,
            {
                "tiles": states,
                "switch": switch,
                "switch_detail": switch_detail,
                "tailscale": tailscale_state,
                "ping": latency,
                "ports": port_state,
            },
        )

    def do_POST(self):
        if not self.guarded():
            return
        parts = self.path.strip("/").split("/")
        if len(parts) != 4 or parts[:2] != ["api", "svc"]:
            return self.reply(404)
        action, name = parts[2], unquote(parts[3])
        if action == "wake" and name in wakeable:
            send_magic_packet(wakeable[name]["mac"])
            return self.reply(202, {"ok": True})
        if action == "poweroff" and wakeable.get(name, {}).get("poweroff") and ssh_key:
            try:
                result = remote(wakeable[name]["host"], "poweroff", wakeable[name]["user"])
            except subprocess.TimeoutExpired:
                return self.reply(504, {"error": "ssh timed out"})
            if result.returncode != 0:
                return self.reply(500, {"error": result.stderr.strip()})
            return self.reply(202, {"ok": True})
        if action == "reboot" and name in rebootable:
            # --no-block so the reply makes it back through nginx before
            # shutdown stops it; polkit allows ignoring inhibitors.
            self.host_action(
                rebootable[name],
                "reboot",
                ["systemctl", "--no-block", "--check-inhibitors=no", "reboot"],
            )
            return
        if action == "switch" and name in switchable:
            target = switchable[name]
            # The remote verb prints the status before the start itself.
            before = ""
            if not target["hosts"] and SWITCH_STATUS:
                before = subprocess.run([SWITCH_STATUS], capture_output=True, text=True).stdout
            started = self.host_action(
                target, "switch", ["systemctl", "--no-block", "start", SWITCH_UNIT]
            )
            if started:
                begin_switch(name, started.stdout if target["hosts"] else before)
                if target["hosts"]:
                    remote_switch[name] = "switching"
                    remote_switch_detail[name] = None
                    start_switch_watch(name)
            return
        if action in ("tailscale-on", "tailscale-off") and name in tailscalable:
            if self.host_action(tailscalable[name], action, None):
                # The next poll confirms it, but the page wants it sooner.
                tailscale_state[name] = "on" if action == "tailscale-on" else "off"
            return
        if action not in ACTIONS or name not in units:
            return self.reply(404)
        if name in remote_units:
            target = remote_units[name]
            if self.host_action(target, f"{action} {target['unit']}", None):
                # The watcher confirms it, but the page wants it sooner.
                remote_unit_state[name] = "deactivating" if action == "stop" else "activating"
                remote_unit_poke[name].set()
            return
        # --no-block: slow stops (Minecraft saving the world) would otherwise
        # hold the request open; the page polls the state instead.
        result = subprocess.run(
            ["systemctl", "--no-block", action, local_units[name]],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            return self.reply(500, {"error": result.stderr.strip()})
        self.reply(202, {"ok": True})

    def log_message(self, format, *args):
        sys.stderr.write("%s\n" % (format % args))


threading.Thread(target=sample_usage, daemon=True).start()
for name, hosts in probed.items():
    threading.Thread(target=probe, args=(name, hosts), daemon=True).start()
for name, target in port_targets.items():
    threading.Thread(target=watch_ports, args=(name, target), daemon=True).start()
if ssh_key:
    for name in remote_switch:
        start_switch_watch(name)
    for name in tailscalable:
        threading.Thread(target=watch_tailscale, args=(name,), daemon=True).start()
    for name in remote_units:
        threading.Thread(target=watch_unit, args=(name,), daemon=True).start()
ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
