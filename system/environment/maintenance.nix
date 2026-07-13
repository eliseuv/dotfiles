{ config, ... }:
{

  # Nix Helper
  programs.nh = {
    enable = true;
    flake = config.dotfiles.path;
    # Disabled: `just update-system` already runs `nh clean` (via the
    # Justfile's `gc` recipe) after every manual switch, so an independent
    # weekly timer only races that flow.
    clean = {
      enable = false;
      dates = "weekly";
      # --no-gcroots: see the Justfile's `gc` recipe for why.
      extraArgs = "--keep 4 --no-gcroots";
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
