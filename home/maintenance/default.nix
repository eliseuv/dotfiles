{ pkgs, config, ... }:
{

  imports = [

    # Nix Index database
    ./nix-index-database.nix

    # Fuzzy search for NixOS packages
    ./nix-search-tv.nix

    # Clean projects to save space
    ./kondo.nix

  ];

  home.packages = with pkgs; [

    # Nix version diff
    nvd

    # Disk recovery tool
    testdisk

  ];

  # Disabled: `just update-home`/`update-system` already update, switch and
  # gc on a regular manual cadence, so the automatic switch/expire/gc timers
  # only add uncoordinated races against that flow (see the Justfile's
  # `gc`, `home-switch`, `update-home`, `update-system` recipes).
  nix.gc = {
    automatic = false;
    options = "--delete-older-than 7d";
    dates = "weekly";
    persistent = true;
    randomizedDelaySec = "45min";
  };

  services.home-manager = {
    autoUpgrade = {
      enable = false;
      frequency = "daily";
      useFlake = true;
      flakeDir = config.dotfiles.path;
      preSwitchCommands = [ ];
    };
    autoExpire = {
      enable = false;
      frequency = "monthly";
      timestamp = "-30 days";
      store = {
        cleanup = true;
        options = "--delete-older-than 30d";
      };
    };
  };

}
