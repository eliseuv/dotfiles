{ config, ... }:
{

  # Nix Helper
  programs.nh = {
    enable = true;
    flake = config.dotfiles.path;
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 4";
    };
  };

  # Periodic garbage collection
  nix.gc = {
    automatic = false;
    dates = "weekly";
    options = "--delete-older-than 7d";
    persistent = true;
    randomizedDelaySec = "45min";
  };

  # Automatic store optimisation
  nix.settings.auto-optimise-store = true;
  nix.optimise = {
    automatic = true;
    persistent = true;
    dates = [ "weekly" ];
    randomizedDelaySec = "45min";

  };

}
