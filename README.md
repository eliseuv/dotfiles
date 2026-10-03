# evf's dotfiles

This repository contains my personal NixOS and Home Manager configuration, managed with **Nix Flakes**.

## Hosts

- **GLaDOS**: Main Workstation
- **wheatley**: Headless Server
- **tardis**: Laptop
- **chell**: Wife's Workstation
- **rattmann**: Old Laptop

## Features

- **OS**: NixOS unstable (a host can follow stable with `my.host.channel`)
- **Home Environment**: standalone Home Manager, driven by the same host spec as NixOS
- **Web Terminal**: `ttyd` for browser-based terminal access on headless nodes
- **Secrets**: [sops-nix](https://github.com/Mic92/sops-nix)
- **Editor**: Neovim (Nightly)
- **Helper Tools**: `nh`, `just`
- **Other Inputs**: `spicetify-nix`, `yt-x`, `catppuccin`, `nix-minecraft`

## Structure

Every host is a directory under `hosts/`, and what it runs is set by `my.*`
options in its spec rather than by import lists. All modules are imported
everywhere and switch themselves on from those options.

- `flake.nix`: Inputs; outputs come from `lib/`.
- `lib/default.nix`: Builds `nixosConfigurations` and `homeConfigurations`
  (`<user>@<host>` for each of the host's `my.host.users`) from `hosts/`.
- `hosts/<host>/`:
  - `default.nix`: The host spec. Sets only `my.*` options, and is read by
    both the NixOS and the Home Manager evaluation, so a feature is enabled
    once for both (e.g. `my.desktop.hyprland.enable` turns on the session and
    the user's Hyprland config).
  - `hardware.nix`: Generated hardware configuration.
  - `system.nix`, `home.nix` (optional): Host-specific settings with no
    option, e.g. extra disks.
  - wheatley's `services/` holds its homelab services.
- `users/<user>.nix`: Who each user is (`my.users.<user>`: git identity,
  uid). Accounts are created on the hosts that list them.
- `modules/shared/`: Declarations of every `my.*` option, part of both
  evaluations. Read them for what a host can set.
- `modules/nixos/`, `modules/home/`: NixOS and Home Manager modules, grouped
  by feature (`core/` is always on, `desktop/`, `apps/`, `homelab/`, ...).
  Every `.nix` file is imported; helpers that aren't modules are named
  `_*.nix`.
- `pkgs/<name>/default.nix`: Packaging for local homebrew projects that
  live in their own repo (e.g. `~/Services/ledger`), fetched from the
  commit pinned in `pkgs/<name>/pin.json`. See "Deploying Local Services"
  below.
- `secrets/`: Encrypted secrets (sops-nix, age): `user.yaml` for home-manager, one file per host for system secrets.

### Adding things

- **A host**: create `hosts/<host>/` with `hardware.nix` and a
  `default.nix` spec; `nixosConfigurations.<host>` appears on its own.
- **A feature**: declare its option in `modules/shared/`, then add modules
  under `modules/nixos/` and/or `modules/home/` wrapped in
  `config = lib.mkIf <option> { ... }`.
- **Checking a refactor**: `just eval-all` prints every configuration's
  derivation; outputs that should not change must print the same.

## Usage

This repository uses [Just](https://github.com/casey/just) to manage common workflows.

### System Management

- **Apply System Configuration**:

  ```bash
  just system-switch
  ```

  *Applies the NixOS configuration, then commits a generation log, garbage collects, and updates home-manager.*

- **Run Post-Switch Steps Only**:

  ```bash
  just after-switch
  ```

  *Commits a generation log, garbage collects, and updates home-manager, without running `nh os switch`. Useful after running `nh os switch .` manually (e.g. `sudo` needs an interactive terminal, which isn't always available when `just system-switch` is invoked through tooling).*

- **Test System Configuration**:

  ```bash
  just system-test
  ```

  *Tests the configuration without switching bootloader, then updates home-manager.*

- **Apply Home Configuration Only**:

  ```bash
  just home-switch
  ```

### Updates & Maintenance

- **Update All System Packages**:

  ```bash
  just update-system
  ```

  *Updates `nixpkgs`, applies system changes, and handles housekeeping.*

- **Update Home Packages**:

  ```bash
  just update-home
  ```

  *Updates `home-manager` and other user inputs, then applies home changes.*

- **Update Specific Flake Inputs**:

  ```bash
  just update <input_name>
  ```

- **Garbage Collection**:

  ```bash
  just gc
  ```

  *Cleans up old generations (keeps last 4 by default).*

### Deploying Local Services

Local homebrew projects (own repo, own git history) that a host runs as a
service — e.g. `~/Services/ledger` on `wheatley`, see `pkgs/ledger-web/` —
are fetched with `builtins.fetchGit` from `file://<path-on-that-host>`, at
the commit pinned in `pkgs/<name>/pin.json`: pushing new code to the
project repo does **not** by itself change what's built or running.

They are deliberately not flake inputs. Every host locks and updates every
flake input, and the repo only exists on the one host that runs it, so
`just update` would fail everywhere else. The `fetchGit` is only forced by
a host whose config uses the package.

One-time setup, per project repo, on the host it deploys to:

```bash
git -C ~/Services/<project> config receive.denyCurrentBranch updateInstead
```

A plain (non-bare) checkout refuses a push to its checked-out branch by
default. `updateInstead` makes the push also update the working tree —
but only if that tree is clean and the push is a fast-forward.

Deploy pipeline, after pushing a new commit (`git push <host-remote>
<branch>` from the project repo, updating the host's checkout per above):

```bash
ssh -t <host> -- 'cd ~/dotfiles && just deploy-service <pkg>'
```

*Bumps `pkgs/<pkg>/pin.json` to the checkout's current commit
(`just pin-service <pkg>`), commits that, then runs `system-switch`.*
Notes:

- `-t` is required: `nh os switch`'s activation step needs a real sudo
  prompt, and there's no askpass helper configured.
- If `<pkg>` was already pinned at the latest commit (e.g. re-running
  after a partial failure), `pin-service` skips without committing and
  `deploy-service` still runs `system-switch`.
- If the switch itself is then also a no-op (same generation, nothing
  changed to activate), `commit-gen` finds its generation tag already
  exists — from the run that actually deployed it — and skips instead of
  failing. Re-running `deploy-service` is safe either way.

Example, deploying ledger to wheatley:

```bash
# In ~/Services/ledger:
git push wheatley wheatley

# Then:
ssh -t evf@wheatley.local -- 'cd ~/dotfiles && just deploy-service ledger-web'
```

#### Automatic deploy-on-push

On wheatley, pushing to `~/Services/ledger` is enough on its own —
`hosts/wheatley/services/ledger/deploy.nix` runs the pipeline above without
a manual `deploy-service` call:

- A `post-receive` hook (installed by `system.activationScripts`, since
  `.git/hooks` isn't itself a path the dotfiles repo can track) touches a
  trigger file on every push.
- A `systemd.path` unit watches that file and runs the deploy chain, split
  by privilege so nothing ever needs sudo or a password: `just
  pin-service ledger-web` as `evf`, then `nh os switch .` as **root** (the service
  itself runs as root, so `nh` never shells out to sudo), then `just
  after-switch` as `evf` again.

The `evf` steps need to push/tag over SSH; they use `evf`'s
`gpg-agent`-backed SSH auth socket, which — because `evf` has
`loginctl linger` enabled — stays up with no session logged in. That
key's passphrase cache (`modules/home/core/auth/gpg.nix`, 12h TTL) can still go cold
with nothing around to unlock it; if so, the tag/push step fails
(`systemctl status ledger-deploy` will show it) even though the actual
deploy — build, activate, `ledger-web.service` restart — already
succeeded. Re-running `just deploy-service ledger-web` by hand, or just
pushing again, clears it.

To add this for another service, copy `services/ledger/deploy.nix`'s shape,
swapping the repo path, `pkgs/<pkg>` name, and the hostname/uid it
already derives at runtime.

## Installation

1. Clone the repository:

   ```bash
   git clone <repo-url> ~/dotfiles
   cd ~/dotfiles
   ```

2. Build/Switch to the configuration for your host:

   ```bash
   # If you have 'just' and 'nh' installed already:
   just system-switch
   
   # Or manually using nixos-rebuild:
   sudo nixos-rebuild switch --flake .#<hostname>
   ```
