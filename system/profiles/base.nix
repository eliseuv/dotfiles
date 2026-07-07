{ ... }:
{

  imports = [

    # Options
    ../modules/dotfiles.nix

    # Bootloader
    ../hardware/bootloader.nix

    # Network
    ../hardware/network.nix

    # Environment
    ../environment/default.nix

  ];

  # Flakes support
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Also set in flake.nix for standalone Home Manager: each nixpkgs
  # evaluation (NixOS here, home-manager there) needs the flag once
  nixpkgs.config.allowUnfree = true;

}
