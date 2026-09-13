# evf's dotfiles

This repository contains my personal NixOS and Home Manager configuration, managed with **Nix Flakes**.

## Hosts

- **GLaDOS**: Main Workstation
- **wheatley**: Headless Server
- **tardis**: Laptop
- **chell**: Wife's Workstation
- **rattmann**: Old Laptop

## Features

- **OS**: NixOS (Unstable for workstations, Stable for servers)
- **Home Environment**: Home Manager (with split GUI and Headless setups)
- **Web Terminal**: `ttyd` for browser-based terminal access on headless nodes
- **Secrets**: [sops-nix](https://github.com/Mic92/sops-nix)
- **Editor**: Neovim (Nightly)
- **Helper Tools**: `nh`, `just`
- **Other Inputs**: `spicetify-nix`, `yt-x`, `antigravity-nix`

## Structure

- `flake.nix`: Entry point and inputs. A single `hosts` matrix declares each
  host's users and nixpkgs branch; `nixosConfigurations` and
  `homeConfigurations` are generated from it.
- `Justfile`: Command runner for common tasks.
- `system/`: System-level configuration.
  - `profiles/`: Composable system profiles (`base.nix` for every machine,
    `desktop.nix` for graphical ones).
  - `hosts/<host>/`: Per-host `configuration.nix` + `hardware.nix`; imports
    profiles and keeps only host-specific settings.
  - `hardware/`, `desktop/`, `environment/`, `extra/`: Individual modules.
- `home/`: User-level configuration (standalone Home Manager).
  - `profiles/`: Composable home profiles (`core.nix` CLI environment,
    `gui.nix` graphical basics, `apps.nix` full workstation apps,
    `hyprland.nix`/`i3.nix` desktops, `gaming.nix`).
  - `hosts/<host>.nix`: What runs on each host; imports profiles plus
    host-specific modules (monitors, syncthing folders, overrides).
  - `users/<user>.nix`: Per-user identity (git name/email).
  - Remaining directories are individual program modules, imported by
    profiles or host files.
- `pkgs/<name>/default.nix`: Packaging for local homebrew projects that
  live in their own repo (e.g. `~/Projects/ledger`), pulled in via a
  `<name>-src` flake input (`flake = false`, `git+file://…`). See
  "Deploying Local Services" below.
- `secrets.yaml`: Encrypted secrets (sops-nix, age).

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
service — e.g. `~/Projects/ledger` on `wheatley`, see `pkgs/ledger-web/` —
are pulled into the flake as a `<name>-src` input pointing at
`git+file://<path-on-that-host>`. Because it's a `git+file://` input, it's
pinned in `flake.lock` to a specific commit: pushing new code to the
project repo does **not** by itself change what's built or running.

One-time setup, per project repo, on the host it deploys to:

```bash
git -C ~/Projects/<project> config receive.denyCurrentBranch updateInstead
```

A plain (non-bare) checkout refuses a push to its checked-out branch by
default. `updateInstead` makes the push also update the working tree —
but only if that tree is clean and the push is a fast-forward.

Deploy pipeline, after pushing a new commit (`git push <host-remote>
<branch>` from the project repo, updating the host's checkout per above):

```bash
ssh -t <host> -- 'cd ~/dotfiles && just deploy-service <input>'
```

*Bumps `<input>` (the `<name>-src` flake input) to the checkout's current
commit in `flake.lock`, commits that, then runs `system-switch`.* Notes:

- `-t` is required: `nh os switch`'s activation step needs a real sudo
  prompt, and there's no askpass helper configured.
- If `<input>` was already at the latest commit (e.g. re-running after a
  partial failure), the `flake.lock` update is a no-op and its commit
  step fails with "nothing to commit" — `deploy-service` tolerates this
  and still runs `system-switch`, same as `update-system`/`update-home`
  tolerate a no-op `update`.
- If the switch itself is then also a no-op (same generation, nothing
  changed to activate), `commit-gen` finds its generation tag already
  exists — from the run that actually deployed it — and skips instead of
  failing. Re-running `deploy-service` is safe either way.

Example, deploying ledger to wheatley:

```bash
# In ~/Projects/ledger:
git push wheatley wheatley

# Then:
ssh -t evf@wheatley.local -- 'cd ~/dotfiles && just deploy-service ledger-src'
```

#### Automatic deploy-on-push

On wheatley, pushing to `~/Projects/ledger` is enough on its own —
`system/hosts/wheatley/ledger-deploy.nix` runs the pipeline above without
a manual `deploy-service` call:

- A `post-receive` hook (installed by `system.activationScripts`, since
  `.git/hooks` isn't itself a path the dotfiles repo can track) touches a
  trigger file on every push.
- A `systemd.path` unit watches that file and runs the deploy chain, split
  by privilege so nothing ever needs sudo or a password: `just update
  ledger-src` as `evf`, then `nh os switch .` as **root** (the service
  itself runs as root, so `nh` never shells out to sudo), then `just
  after-switch` as `evf` again.

The `evf` steps need to push/tag over SSH; they use `evf`'s
`gpg-agent`-backed SSH auth socket, which — because `evf` has
`loginctl linger` enabled — stays up with no session logged in. That
key's passphrase cache (`home/auth/gpg.nix`, 12h TTL) can still go cold
with nothing around to unlock it; if so, the tag/push step fails
(`systemctl status ledger-deploy` will show it) even though the actual
deploy — build, activate, `ledger-web.service` restart — already
succeeded. Re-running `just deploy-service ledger-src` by hand, or just
pushing again, clears it.

To add this for another service, copy `ledger-deploy.nix`'s shape,
swapping the repo path, `<name>-src` input, and the hostname/uid it
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
