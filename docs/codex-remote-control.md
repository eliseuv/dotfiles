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

To continue a phone session in the terminal, run `codex-phone` on the host.
This alias opens the service's resume picker across all project directories.
To resume a specific session directly, run `codex-phone <session-id>`.

## Aven from remote sessions

Remote sessions use the host's local aven client, not the encrypted sync-server
SQLite file. With aven enabled, Home Manager installs the `capture`, `triage`,
`scope`, and `audit` skills, loads the shared conventions into Codex's global
`AGENTS.md`, and allows access to the aven state/configuration directories and
`~/Documents/ideas`. The existing aven command policy also applies remotely.

A host running the sync server still needs its own client joined to the sync.
To join Wheatley's empty client to existing data:

1. On an already synced device such as GLaDOS, run `aven sync invite` and leave
   it running.
2. In a terminal on Wheatley, run `aven sync join` and paste the invitation.
3. After joining, enable background sync and start the client daemon:

   ```sh
   aven config set sync.enabled true
   systemctl --user restart aven-daemon.service
   aven sync status
   aven project list
   ```

Keep invitations out of files, commits, and logs. Do not run `aven sync setup`
on the empty client to access existing data: `join` gets its keys and data
from an already authorized device. The encrypted server database is not a
client database and must not be passed to `aven --db`.

Start a new remote chat after changing global instructions or sandbox roots.
Use `aven doctor` to confirm the client database and sync state on that host.
