# Chell Host Configuration

This directory contains the NixOS system configuration specific to the `chell` host.

## Multi-User Setup & Home Manager

`chell` is configured as a multi-user machine (supporting users like `evf` and `dani`). Because Home Manager is installed standalone rather than as a NixOS module, each user must run `home-manager switch` individually.

To ensure both users have the necessary permissions to read the flake and apply their configurations, the dotfiles repository is stored in a shared directory rather than a single user's home folder.

### Shared Dotfiles Location

The repository is located at:
`/etc/dotfiles`

Both users (`evf` and `dani`) are part of the `dotfiles` group. With `my.dotfiles.shared = true`, `modules/nixos/core/dotfiles.nix` keeps the directory `2775 evf:dotfiles` and applies a recursive ACL granting the group read/write, plus a default ACL so new files stay group-writable regardless of umask. The rules are reapplied at boot and on every switch, so a fresh clone into `/etc/dotfiles` is fixed by the next `nixos-rebuild switch` (or `sudo systemd-tmpfiles --create`).

### Applying Configurations

When applying updates on this machine, point to the shared flake repository:

**NixOS Rebuild (System-wide):**
```bash
sudo nixos-rebuild switch --flake /etc/dotfiles#chell
```

**Home Manager (Per-user):**
```bash
home-manager switch --flake /etc/dotfiles#<username>@chell
```

### Git Safe Directory

The repository is owned by `evf`, so git refuses it for other users as "dubious ownership" unless it is listed in `safe.directory`. Each user's Home Manager git config lists it, and the same module adds it to the system-wide `/etc/gitconfig` for git running as root under `sudo`.
