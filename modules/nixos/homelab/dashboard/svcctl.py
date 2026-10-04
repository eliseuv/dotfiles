"""svcctl PORT UNITS_JSON WAKE_JSON REBOOT_JSON [POWEROFF_KEY]: start/stop/
restart a fixed set of systemd units for the dashboard's tile buttons
(controls.nix).
UNITS_JSON maps tile names to units; nothing else can be touched, and polkit
enforces the same list. WAKE_JSON maps tile names to {mac, host, poweroff} for
tiles that wake another machine: Wake-on-LAN instead of a unit, and up/down
from pinging `host`. Those with `poweroff` are powered off by an SSH login with
POWEROFF_KEY, which the host pins to a forced `shutdown +1`. REBOOT_JSON lists
tiles for this host itself, which reboot it."""

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
poweroff_key = sys.argv[5] if len(sys.argv) > 5 else None

ACTIONS = {"start", "stop", "restart"}


# Tile name -> "up"/"down", kept fresh by probe() rather than pinged per
# request: a sleeping host's mDNS lookup alone takes ~9s to fail.
reachable = {name: "unknown" for name in wakeable}


def probe(name, host):
    while True:
        try:
            result = subprocess.run(
                ["ping", "-c1", "-W1", host],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=15,
            )
            reachable[name] = "up" if result.returncode == 0 else "down"
        except subprocess.TimeoutExpired:
            reachable[name] = "down"
        time.sleep(5)


def send_magic_packet(mac):
    payload = b"\xff" * 6 + bytes.fromhex(mac.replace(":", "")) * 16
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(payload, ("255.255.255.255", 9))


def power_off(host):
    # No command: the host's authorized_keys forces one. known_hosts comes
    # from the system file only; svcctl has no home to keep one in.
    return subprocess.run(
        [
            "ssh",
            "-i", poweroff_key,
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=5",
            "-o", "StrictHostKeyChecking=yes",
            "-o", "UserKnownHostsFile=/dev/null",
            f"remote-poweroff@{host}",
        ],
        capture_output=True,
        text=True,
        timeout=20,
    )


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

    def do_GET(self):
        if not self.guarded():
            return
        if self.path != "/api/svc/status":
            return self.reply(404)
        states = dict(reachable)
        # This host is up for as long as it's answering.
        states.update((name, "up") for name in rebootable)
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
        self.reply(200, states)

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
        if action == "poweroff" and wakeable.get(name, {}).get("poweroff") and poweroff_key:
            try:
                result = power_off(wakeable[name]["host"])
            except subprocess.TimeoutExpired:
                return self.reply(504, {"error": "ssh timed out"})
            if result.returncode != 0:
                return self.reply(500, {"error": result.stderr.strip()})
            return self.reply(202, {"ok": True})
        if action == "reboot" and name in rebootable:
            # --no-block so the reply makes it back through nginx before
            # shutdown stops it; polkit allows ignoring inhibitors.
            result = subprocess.run(
                ["systemctl", "--no-block", "--check-inhibitors=no", "reboot"],
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                return self.reply(500, {"error": result.stderr.strip()})
            return self.reply(202, {"ok": True})
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


for name, target in wakeable.items():
    threading.Thread(target=probe, args=(name, target["host"]), daemon=True).start()
ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
