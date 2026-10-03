# Chell Host Configuration

This directory contains the NixOS system configuration specific to the `chell` host.

## Multi-User Setup & Home Manager

`chell` is configured as a multi-user machine (supporting users like `evf` and `dani`). Because Home Manager is installed standalone rather than as a NixOS module, each user must run `home-manager switch` individually.

To ensure both users have the necessary permissions to read the flake and apply their configurations, the dotfiles repository is stored in a shared directory rather than a single user's home folder.

### Shared Dotfiles Location

The repository is located at:
`/etc/dotfiles`

Both users (`evf` and `dani`) are part of the `dotfiles` group, which grants them read and write access to this directory.

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

### Git Safe Directory & Flake Ownership

Because the repository is owned by `evf`, when `dani` runs `home-manager` or when running `sudo nixos-rebuild`, Nix (and Git) will complain about "dubious ownership". Nix evaluates flakes in an isolated environment, so setting this in your user `~/.gitconfig` is often ignored.

To fix this permanently for the whole system, run:

```bash
sudo git config --system --add safe.directory /etc/dotfiles
```

**Alternative Workaround:**
If Nix still complains about ownership, you can force Nix to treat the folder as a regular directory instead of a Git repository by prefixing the path with `path:` like this:

```bash
home-manager switch --flake path:/etc/dotfiles#dani@chell
```
