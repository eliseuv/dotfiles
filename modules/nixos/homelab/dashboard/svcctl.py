"""svcctl PORT UNITS_JSON WAKE_JSON: start/stop/restart a fixed set of systemd
units for the dashboard's tile buttons (controls.nix). UNITS_JSON maps tile
names to units; nothing else can be touched, and polkit enforces the same
list. WAKE_JSON maps tile names to {mac, host} for tiles that wake another
machine: Wake-on-LAN instead of a unit, and up/down from pinging `host`."""

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
