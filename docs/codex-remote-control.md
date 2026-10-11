# Codex remote control

Hosts with `my.home.remoteAccess.enable` run `codex-remote-control.service`
and install `codex-remote-pair` through Home Manager. After switching the
home configuration, sign in with ChatGPT and pair the app:

```sh
codex login
systemctl --user restart codex-remote-control.service
codex-remote-pair --status
codex-remote-pair
```

Enter the printed short-lived code in the app's manual pairing flow.
`codex-remote-pair --json` prints the full pairing response instead.
Pairing creates a code; it does not complete the app-side step for you.

## Why a helper is needed

The service listens on
`$XDG_RUNTIME_DIR/codex-remote-control/app-server.sock`. Codex 0.160.1's
`codex remote-control pair` looks for the managed daemon's default socket,
`~/.codex/app-server-control/app-server-control.sock`, and provides no
socket override.

The private socket is intentional: publishing the service at the default
location allows interactive Codex sessions to attach to it automatically.
Those sessions would inherit the service environment rather than the
terminal's devshell/direnv environment.

The helper connects directly to the private Unix socket over WebSocket,
initializes the experimental app-server protocol, checks
`remoteControl/status/read`, and calls `remoteControl/pairing/start` with
`manualCode: true`. It creates no symlink and starts no additional daemon.
These experimental RPCs were verified against Codex 0.160.1; a future
protocol change may require updating the helper.

## Troubleshooting and persistence

A running systemd service or a `connected` remote status does not establish
that the app is paired. If the host is missing from the app, check status
and run the pairing helper, then complete pairing in the app.

If status is not connected, check `codex login status` and
`systemctl --user status codex-remote-control.service`. Authentication
changes may require restarting the service. Detailed remote transport
logs are stored in `~/.codex/logs_2.sqlite`; the systemd journal may only
show service starts and stops.

Enrollment is persisted under `~/.codex` and reused on service restart.
Pairing should survive reboot and NixOS/Home Manager switches as long as
that state, the account, and the enabled service are preserved.

If the default socket was previously symlinked to the private socket,
remove that specific symlink after pairing to restore terminal isolation.
Inspect it first with:

```sh
ls -l ~/.codex/app-server-control/app-server-control.sock
```

Only if it is the workaround symlink pointing to this service:

```sh
unlink ~/.codex/app-server-control/app-server-control.sock
```

To deliberately attach a terminal to the service:

```sh
codex --remote "unix://$XDG_RUNTIME_DIR/codex-remote-control/app-server.sock"
```
