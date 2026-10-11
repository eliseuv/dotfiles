"""Pair the systemd Codex service without publishing its default socket."""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import socket
import sys
import time

import websocket


def request(connection, request_id, method, params):
    connection.send(json.dumps({"id": request_id, "method": method, "params": params}))
    deadline = time.monotonic() + 30
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError(f"Timed out waiting for {method}")
        connection.settimeout(remaining)
        response = json.loads(connection.recv())
        if response.get("id") != request_id:
            continue
        if "error" in response:
            raise RuntimeError(response["error"]["message"])
        return response["result"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Print the pairing response as JSON")
    parser.add_argument("--status", action="store_true", help="Read connection status without pairing")
    args = parser.parse_args()
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    path = Path(runtime) / "codex-remote-control/app-server.sock"
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as transport:
            transport.settimeout(30)
            transport.connect(str(path))
            connection = websocket.create_connection(
                "ws://localhost/", socket=transport, timeout=30
            )
            try:
                request(connection, 1, "initialize", {
                    "clientInfo": {"name": "codex_remote_pair", "version": "1.0"},
                    "capabilities": {"experimentalApi": True},
                })
                connection.send(json.dumps({"method": "initialized"}))
                status = request(connection, 2, "remoteControl/status/read", None)
                if args.status:
                    print(json.dumps(status) if args.json else
                          f"{status['serverName']}: {status['status']}")
                    return 0
                if status["status"] != "connected":
                    raise RuntimeError(
                        f"Remote control is {status['status']}; check ChatGPT login and the service"
                    )
                pairing = request(connection, 3, "remoteControl/pairing/start", {"manualCode": True})
                if args.json:
                    print(json.dumps(pairing))
                else:
                    code = pairing.get("manualPairingCode")
                    if not code:
                        raise RuntimeError("Server did not return a manual pairing code")
                    expires = datetime.fromtimestamp(pairing["expiresAt"], timezone.utc)
                    print(f"Pair {status['serverName']} in the app using code: {code}")
                    print(f"Expires: {expires.isoformat()}")
            finally:
                connection.close()
    except (OSError, RuntimeError, ValueError, websocket.WebSocketException) as error:
        print(f"codex-remote-pair: {error}", file=sys.stderr)
        print("Check: systemctl --user status codex-remote-control.service", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
