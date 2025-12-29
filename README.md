# evf's dotfiles

This repository contains my personal NixOS and Home Manager configuration, managed with **Nix Flakes**.

## Hosts

- **GLaDOS**: Main Workstation
- **tardis**: Laptop

## Features

- **OS**: NixOS (Unstable)
- **Home Environment**: Home Manager
- **Secrets**: [sops-nix](https://github.com/Mic92/sops-nix)
- **Editor**: Neovim (Nightly)
- **Helper Tools**: `nh`, `just`
- **Other Inputs**: `spicetify-nix`, `yt-x`, `antigravity-nix`

## Structure

- `flake.nix`: Entry point and inputs.
- `Justfile`: Command runner for common tasks.
- `system/`: System-level configurations (hosts, hardware, etc.).
- `home/`: User-level configurations (programs, services, etc.).
- `secrets.yaml`: Encrypted secrets.

## Usage

This repository uses [Just](https://github.com/casey/just) to manage common workflows.

### System Management

- **Apply System Configuration**:

  ```bash
  just system-switch
  ```

  *Applies the NixOS configuration, then commits a generation log, garbage collects, and updates home-manager.*

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

  *Cleans up old generations (keeps last 8 by default).*

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
