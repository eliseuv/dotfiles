{ config, ... }:
{

  # Flakes support
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Also set in flake.nix for standalone Home Manager: each nixpkgs
  # evaluation (NixOS here, home-manager there) needs the flag once
  nixpkgs.config.allowUnfree = true;

  networking.hostName = config.my.host.name;

  system.stateVersion = config.my.host.stateVersion;

}
