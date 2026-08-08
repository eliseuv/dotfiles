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
