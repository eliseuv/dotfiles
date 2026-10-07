"""svcctl PORT UNITS_JSON WAKE_JSON REBOOT_JSON SWITCH_JSON TAILSCALE_JSON [SSH_KEY]:
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
be turned on and off, always through that login.
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
ssh_key = sys.argv[7] if len(sys.argv) > 7 else None

ACTIONS = {"start", "stop", "restart"}
SWITCH_UNIT = "dotfiles-switch.service"


local_units = {name: target["unit"] for name, target in units.items() if not target["hosts"]}
remote_units = {name: target for name, target in units.items() if target["hosts"]}

# Tile name -> hosts to ping for up/down, up if any answers: wake tiles, and
# remote reboot, switch, tailscale and unit tiles that aren't also wake tiles.
probed = {name: [target["host"]] for name, target in wakeable.items()}
for targets in (rebootable, switchable, tailscalable, remote_units):
    for name, target in targets.items():
        if target["hosts"] and name not in probed:
            probed[name] = target["hosts"]

# Tile name -> "up"/"down", kept fresh by probe() rather than pinged per
# request: a sleeping host's mDNS lookup alone takes ~9s to fail.
reachable = {name: "unknown" for name in probed}

# Tile name -> "idle"/"switching"/"failed" for remote switch tiles, from
# watch_switch(); the local one is read from systemd on each request.
remote_switch = {
    name: "unknown" for name, target in switchable.items() if target["hosts"]
}


# Tile name -> "on"/"off"/"unknown" for Tailscale tiles, from watch_tailscale().
tailscale_state = {name: "unknown" for name in tailscalable}


# Tile name -> `systemctl is-active` output for remote unit tiles, from
# watch_unit(); its event wakes the watcher early after an action.
remote_unit_state = {name: "unknown" for name in remote_units}
remote_unit_poke = {name: threading.Event() for name in remote_units}


# Tile name -> round-trip time in ms of the last answered ping, None while down.
latency = {name: None for name in probed}


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


def local_switch_state():
    result = subprocess.run(
        ["systemctl", "show", "--property=ActiveState,Result", "--value", SWITCH_UNIT],
        capture_output=True,
        text=True,
    )
    return switch_state(result.stdout)


def watch_switch(name, until_done):
    # Polled over SSH only around switches started from here, plus once at
    # startup, rather than on every status request: each poll is a login.
    hosts = switchable[name]["hosts"]
    while True:
        try:
            result = remote_any(hosts, "switch-status", switchable[name]["user"])
            if result.returncode == 0:
                remote_switch[name] = switch_state(result.stdout)
        except subprocess.TimeoutExpired:
            pass
        if not until_done or remote_switch[name] != "switching":
            return
        time.sleep(10)


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
        # `verb` over SSH on the first of them that connects. Replies, and says
        # whether it worked.
        hosts = target["hosts"]
        if hosts and not ssh_key:
            self.reply(404)
            return False
        try:
            if hosts:
                result = remote_any(hosts, verb, target["user"])
            else:
                result = subprocess.run(local_command, capture_output=True, text=True)
        except subprocess.TimeoutExpired:
            self.reply(504, {"error": "ssh timed out"})
            return False
        if result.returncode != 0:
            self.reply(500, {"error": result.stderr.strip()})
            return False
        self.reply(202, {"ok": True})
        return True

    def do_GET(self):
        if not self.guarded():
            return
        if self.path == "/api/svc/usage":
            return self.reply(
                200, {"cores": os.cpu_count(), "memory_total": memory_total(), "services": usage}
            )
        if self.path != "/api/svc/status":
            return self.reply(404)
        states = dict(reachable)
        # This host is up for as long as it's answering.
        states.update(
            (name, "up") for name, target in rebootable.items() if not target["hosts"]
        )
        switch = dict(remote_switch)
        local = [name for name, target in switchable.items() if not target["hosts"]]
        if local:
            state = local_switch_state()
            switch.update((name, state) for name in local)
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
            200, {"tiles": states, "switch": switch, "tailscale": tailscale_state, "ping": latency}
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
            hosts = switchable[name]["hosts"]
            started = self.host_action(
                switchable[name], "switch", ["systemctl", "--no-block", "start", SWITCH_UNIT]
            )
            if started and hosts:
                remote_switch[name] = "switching"
                threading.Thread(target=watch_switch, args=(name, True), daemon=True).start()
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
if ssh_key:
    for name in remote_switch:
        threading.Thread(target=watch_switch, args=(name, False), daemon=True).start()
    for name in tailscalable:
        threading.Thread(target=watch_tailscale, args=(name,), daemon=True).start()
    for name in remote_units:
        threading.Thread(target=watch_unit, args=(name,), daemon=True).start()
ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
