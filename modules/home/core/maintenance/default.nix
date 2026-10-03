{
  config,
  inputs,
  pkgs,
  ...
}:
{

  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  home.packages = with pkgs; [

    # Nix version diff
    nvd

    # Disk recovery tool
    testdisk

  ];

  # Run anything from nixpkgs with `, <command>`; fuzzy package search
  programs.nix-index-database.comma.enable = true;
  programs.nix-search-tv.enable = true;

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
      flakeDir = config.my.dotfiles.path;
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
