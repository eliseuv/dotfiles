"""svcctl PORT UNITS_JSON WAKE_JSON REBOOT_JSON SWITCH_JSON [SSH_KEY]:
start/stop/restart a fixed set of systemd units for the dashboard's tile
buttons (controls.nix).
UNITS_JSON maps tile names to units; nothing else can be touched, and polkit
enforces the same list. WAKE_JSON maps tile names to {mac, host, poweroff} for
tiles that wake another machine: Wake-on-LAN instead of a unit, and up/down
from pinging `host`. Those with `poweroff` are powered off by an SSH login with
SSH_KEY, which the host pins to its remote-control forced command.
REBOOT_JSON and SWITCH_JSON map tile names to {hosts} for hosts that can be
rebooted, or whose dotfiles-switch.service can be started: here when `hosts`
is empty, otherwise through the same SSH login, trying each name in turn until
one connects."""

import json
import socket
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
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
ssh_key = sys.argv[6] if len(sys.argv) > 6 else None

ACTIONS = {"start", "stop", "restart"}
SWITCH_UNIT = "dotfiles-switch.service"


# Tile name -> hosts to ping for up/down, up if any answers: wake tiles, and
# remote reboot and switch tiles that aren't also wake tiles.
probed = {name: [target["host"]] for name, target in wakeable.items()}
for targets in (rebootable, switchable):
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


def ping(host):
    try:
        result = subprocess.run(
            ["ping", "-c1", "-W1", host],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=15,
        )
    except subprocess.TimeoutExpired:
        return False
    return result.returncode == 0


def probe(name, hosts):
    while True:
        reachable[name] = "up" if any(ping(host) for host in hosts) else "down"
        time.sleep(5)


def send_magic_packet(mac):
    payload = b"\xff" * 6 + bytes.fromhex(mac.replace(":", "")) * 16
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(payload, ("255.255.255.255", 9))


def remote(host, verb):
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
            f"remote-control@{host}",
            verb,
        ],
        capture_output=True,
        text=True,
        timeout=20,
    )


def remote_any(hosts, verb):
    # ssh exits 255 when it can't connect (or log in), anything else is the
    # forced command's own exit; only the former moves on to the next name.
    # Raises the last TimeoutExpired if every name timed out.
    result = timeout = None
    for host in hosts:
        try:
            result = remote(host, verb)
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
            result = remote_any(hosts, "switch-status")
            if result.returncode == 0:
                remote_switch[name] = switch_state(result.stdout)
        except subprocess.TimeoutExpired:
            pass
        if not until_done or remote_switch[name] != "switching":
            return
        time.sleep(10)


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

    def host_action(self, hosts, verb, local_command):
        # Runs `local_command` here when `hosts` is empty, else `verb` over SSH
        # on the first of `hosts` that connects. Replies, and says whether it
        # worked.
        if hosts and not ssh_key:
            self.reply(404)
            return False
        try:
            if hosts:
                result = remote_any(hosts, verb)
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
        if units:
            names = list(units)
            # One state per line, in argument order; non-zero exit when any
            # unit is inactive, which is not an error here.
            result = subprocess.run(
                ["systemctl", "is-active", *(units[name] for name in names)],
                capture_output=True,
                text=True,
            )
            states.update(zip(names, result.stdout.split()))
        self.reply(200, {"tiles": states, "switch": switch})

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
                result = remote(wakeable[name]["host"], "poweroff")
            except subprocess.TimeoutExpired:
                return self.reply(504, {"error": "ssh timed out"})
            if result.returncode != 0:
                return self.reply(500, {"error": result.stderr.strip()})
            return self.reply(202, {"ok": True})
        if action == "reboot" and name in rebootable:
            # --no-block so the reply makes it back through nginx before
            # shutdown stops it; polkit allows ignoring inhibitors.
            self.host_action(
                rebootable[name]["hosts"],
                "reboot",
                ["systemctl", "--no-block", "--check-inhibitors=no", "reboot"],
            )
            return
        if action == "switch" and name in switchable:
            hosts = switchable[name]["hosts"]
            started = self.host_action(
                hosts, "switch", ["systemctl", "--no-block", "start", SWITCH_UNIT]
            )
            if started and hosts:
                remote_switch[name] = "switching"
                threading.Thread(target=watch_switch, args=(name, True), daemon=True).start()
            return
        if action not in ACTIONS or name not in units:
            return self.reply(404)
        # --no-block: slow stops (Minecraft saving the world) would otherwise
        # hold the request open; the page polls the state instead.
        result = subprocess.run(
            ["systemctl", "--no-block", action, units[name]],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            return self.reply(500, {"error": result.stderr.strip()})
        self.reply(202, {"ok": True})

    def log_message(self, format, *args):
        sys.stderr.write("%s\n" % (format % args))


for name, hosts in probed.items():
    threading.Thread(target=probe, args=(name, hosts), daemon=True).start()
if ssh_key:
    for name in remote_switch:
        threading.Thread(target=watch_switch, args=(name, False), daemon=True).start()
ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
