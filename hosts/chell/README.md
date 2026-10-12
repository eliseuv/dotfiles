# Chell Host Configuration

This directory contains the NixOS system configuration specific to the `chell` host.

## Multi-User Setup & Home Manager

`chell` is a shared family workstation for `evf` and `dani`. Home Manager is installed standalone rather than as a NixOS module, but nobody has to switch each home by hand: `dj home-switch` (and so `dj system-switch`, and the dashboard's switch button) switches the current user's home and then every other user's on this host, through `sudo`.

To ensure both users have the necessary permissions to read the flake and apply their configurations, the dotfiles repository is stored in a shared directory rather than a single user's home folder.

### Per-User Homes

`default.nix` is the host spec: what NixOS installs, and every user's home by default. Each user's departures from it live in `home-<user>.nix`, imported into that user's Home Manager only (values the spec sets need `lib.mkForce` there).

- **evf** (`home-evf.nix`): the GLaDOS setup, with Hyprland and waybar across both monitors, tailnet, ttyd and the dashboard's switch button. Caps Lock is Escape per session, because kanata, which would remap every user's keyboard, is off on chell (`system.nix`).
- **dani** (`home-dani.nix`): GNOME in Portuguese with a dock, tray icons, minimize/maximize buttons, GNOME's own viewers and LibreOffice. It keeps evf's shell and dev environment, and drops evf's Hyprland, Syncthing, rclone and remote access.

GDM starts GNOME for anyone without a saved choice. The first time the system boots with this config, `modules/nixos/desktop/accounts.nix` gives dani Portuguese and evf Hyprland, but only if their accounts have no language or session yet. After that, whatever they pick at the GDM gear or in GNOME Settings sticks. evf's account already remembers GNOME, so evf has to pick Hyprland at the gear once.

### Shared Dotfiles Location

The repository is located at:
`/etc/dotfiles`

Both users (`evf` and `dani`) are part of the `dotfiles` group. With `my.dotfiles.shared = true`, `modules/nixos/core/dotfiles.nix` keeps the directory `2775 evf:dotfiles` and applies a recursive ACL granting the group read/write, plus a default ACL so new files stay group-writable regardless of umask. The rules are reapplied at boot and on every switch, so a fresh clone into `/etc/dotfiles` is fixed by the next `nixos-rebuild switch` (or `sudo systemd-tmpfiles --create`).

### Applying Configurations

From anywhere, as either user:

```bash
dj system-switch   # system, then both homes
dj home-switch     # both homes
```

Without `dj` (before the first home switch):

```bash
sudo nixos-rebuild switch --flake /etc/dotfiles#chell
home-manager switch --flake /etc/dotfiles#<username>@chell
```

`commit-gen` keeps the generation tag local when the user can't push to GitHub, and the next push from someone who can carries it along.

### Tailnet and Dashboard

Once, after the first switch:

1. `sudo tailscale up` on chell.
2. Set `chellAddress` in `hosts/wheatley/system.nix` to chell's tailnet address, so the dashboard gets a terminal button and proxy, and switch wheatley.

### Git Safe Directory

The repository is owned by `evf`, so git refuses it for other users as "dubious ownership" unless it is listed in `safe.directory`. Each user's Home Manager git config lists it, and the same module adds it to the system-wide `/etc/gitconfig` for git running as root under `sudo`.
