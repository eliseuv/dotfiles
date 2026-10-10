# pop-os: the Pop!_OS desktop, set up by hand

pop-os is not a host in this flake (it has no Nix at all), but wheatley's
dashboard has a tile for it (`homelab.services.pop-os` in
`hosts/wheatley/system.nix`) with wake, restart, on/off, Tailscale and
terminal buttons. Everything those buttons need on the pop-os side is set up
by hand, mirroring these NixOS modules:

| Here | Mirrors |
|---|---|
| `remote-control` user, forced command, sudoers, polkit, PAM | `modules/nixos/services/remote-control.nix` |
| `tailscale-up-at-boot.service` | `modules/nixos/services/tailscale.nix` |
| `ttyd.service`, ufw rule | `modules/nixos/services/ttyd.nix`, GLaDOS's firewall |
| Wake-on-LAN on the NIC | `modules/shared/wake-on-lan.nix` |

When one of those modules changes, re-check this host against it. Verbs that
need NixOS generations (`switch`, `switch-status`, `generations`, `diff`) have
no equivalent here, so pop-os has no switch button or host page.

Everything below runs as root.

## remote-control login

The dashboard (svcctl on wheatley) logs in as `remote-control` with the
`svcctl/poweroff-ssh-key` key from `secrets/hosts/wheatley.yaml`, which is
pinned to one forced command. The `useradd` below is a reconstruction that
matches the existing account (system uid 999, `/bin/sh`), not a record of the
original command.

```sh
useradd --system --home-dir /var/lib/remote-control --create-home \
  --shell /bin/sh remote-control
install -d -m 700 -o remote-control -g remote-control /var/lib/remote-control/.ssh
echo 'restrict,command="/usr/local/bin/remote-control" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBkYyj2vQNoL702tMIZPdaLAXt6qNA9loALCYKBij9Sx svcctl@wheatley' \
  > /var/lib/remote-control/.ssh/authorized_keys
chown remote-control:remote-control /var/lib/remote-control/.ssh/authorized_keys
chmod 600 /var/lib/remote-control/.ssh/authorized_keys
```

`/usr/local/bin/remote-control` (mode 755):

```sh
#!/bin/sh
case "${SSH_ORIGINAL_COMMAND:-}" in
poweroff) exec /usr/bin/systemctl --no-block --check-inhibitors=no poweroff ;;
reboot) exec /usr/bin/systemctl --no-block --check-inhibitors=no reboot ;;
tailscale-on) exec sudo -n /usr/bin/tailscale up --timeout=10s --operator=evf ;;
tailscale-off) exec sudo -n /usr/bin/tailscale down ;;
tailscale-status) exec /usr/bin/tailscale status --json --peers=false ;;
*)
  echo "remote-control: refused: ${SSH_ORIGINAL_COMMAND:-<none>}" >&2
  exit 1
  ;;
esac
```

The NixOS hosts run `tailscale up/down` through root oneshot units that polkit
lets this user start. Here, sudo allows those two exact command lines instead.
`/etc/sudoers.d/remote-control` (mode 440, check with `visudo -c`):

```
remote-control ALL=(root) NOPASSWD: /usr/bin/tailscale up --timeout=10s --operator=evf, /usr/bin/tailscale down
```

Pop!_OS's polkit only reads `.pkla` files, not JavaScript rules.
`/etc/polkit-1/localauthority/50-local.d/remote-control.pkla` lets this user
power off and reboot, including while someone is logged in or a desktop
session holds an inhibitor lock:

```ini
[remote-control power]
Identity=unix-user:remote-control
Action=org.freedesktop.login1.power-off;org.freedesktop.login1.power-off-multiple-sessions;org.freedesktop.login1.power-off-ignore-inhibit;org.freedesktop.login1.reboot;org.freedesktop.login1.reboot-multiple-sessions;org.freedesktop.login1.reboot-ignore-inhibit
ResultAny=yes
ResultInactive=yes
ResultActive=yes
```

### No logind session

The dashboard polls every 30s. Without this change, each login starts
`user@999.service` and tears it down again about 10s later. On NixOS a
`pam_succeed_if` rule jumps over `pam_systemd`. Debian's `@include` splices
the included file's lines in place, so a jump can't skip `pam_systemd` alone
from `/etc/pam.d/sshd`, and editing `common-session` is fragile because
pam-auth-update regenerates it. Instead, in `/etc/pam.d/sshd`, replace
`@include common-session` with:

```
# remote-control (the homelab dashboard's forced-command login) gets no
# logind session, so its polls don't start user@.service each time.
session [success=2 default=ignore] pam_succeed_if.so quiet user = remote-control
session substack common-session
session [success=1 default=ignore] pam_permit.so
session substack common-session-noninteractive
```

A substack counts as one module for jumps. So `remote-control` gets
`common-session-noninteractive`, which is `common-session` without
`pam_systemd`, and everyone else is unchanged. Keep a root shell open while
editing this, and test a normal `ssh` login before closing it. An
openssh-server upgrade may offer to replace this file (it's a conffile), so
keep the local version.

## Tailscale

Tailscale is installed from its apt repository, with `evf` as operator
(`tailscale set --operator=evf`). Like `tailscale.upAtBoot`, a oneshot brings
it back up at every boot, undoing a dashboard `tailscale-off` from the last
session. `/etc/systemd/system/tailscale-up-at-boot.service`:

```ini
[Unit]
Description=Bring Tailscale up at boot
After=tailscaled.service
Requires=tailscaled.service

[Service]
Type=oneshot
ExecStart=/usr/bin/tailscale up --timeout=60s --operator=evf

[Install]
WantedBy=multi-user.target
```

```sh
systemctl daemon-reload && systemctl enable tailscale-up-at-boot.service
```

Root's `tailscale up` refuses to run unless it repeats every non-default
setting. If you add any (e.g. `--accept-routes`), add them both here and in
the forced command and sudoers line above.

## Terminal (ttyd)

ttyd comes from apt. wheatley's nginx proxies `/pop-os/terminal/` to
`100.68.2.108:3000`, pop-os's tailnet address. If that address ever changes,
update `hosts/wheatley/system.nix`. `/etc/systemd/system/ttyd.service`:

```ini
[Unit]
Description=ttyd web terminal
After=network.target tailscaled.service

[Service]
User=evf
Group=evf
WorkingDirectory=/home/evf
# No login of its own: wheatley's dashboard nginx is the only way in. Bound
# to the tailnet interface, which may not exist yet at boot, hence the retry.
ExecStart=/usr/bin/ttyd -p 3000 -i tailscale0 -b /pop-os/terminal \
  -t 'theme={"background":"#1e1e2e","foreground":"#cdd6f4","cursor":"#f5e0dc","cursorAccent":"#1e1e2e","selection":"#585b70","black":"#45475a","red":"#f38ba8","green":"#a6e3a1","yellow":"#f9e2af","blue":"#89b4fa","magenta":"#f5c2e7","cyan":"#94e2d5","white":"#bac2de","brightBlack":"#585b70","brightRed":"#f38ba8","brightGreen":"#a6e3a1","brightYellow":"#f9e2af","brightBlue":"#89b4fa","brightMagenta":"#f5c2e7","brightCyan":"#94e2d5","brightWhite":"#a6adc8"}' \
  -t 'fontFamily=IosevkaTerm Nerd Font' \
  /usr/bin/zsh -l
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

The terminal has no login of its own, so only wheatley (`100.97.1.97`) may
reach it:

```sh
ufw allow in on tailscale0 from 100.97.1.97 to any port 3000 proto tcp
```

## Wake-on-LAN

The NIC's MAC (`b4:2e:99:6e:1a:bd`) is in `modules/shared/wake-on-lan.nix`.
Arm magic-packet wake on the wired connection:

```sh
nmcli connection modify <wired connection> 802-3-ethernet.wake-on-lan magic
```

## Checking it works

Watch the journal while the dashboard polls:

```sh
journalctl -f | grep -E 'remote-control|user@999'
```

Each poll should show only `Accepted publickey`, then `pam_unix` session
opened and closed. There should be no `New session … of user remote-control`,
no `user@999.service` and no `refused`.
