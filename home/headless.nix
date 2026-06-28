{ pkgs, inputs, ... }:
{

  imports = [

    # Shell environment
    ./shell/default.nix

    # Authentication
    ./auth/default.nix

    # Maintenance
    ./maintenance/default.nix

    # Development
    ./development/default.nix

    # Containers
    ./containers/default.nix

    # Text editors (TUI only)
    ./editor/neovim/default.nix
    ./editor/helix.nix

    # Services (headless only)
    ./services/pueue.nix
    ./services/syncthing/default.nix

  ];

  home = {
    username = "evf";
    homeDirectory = "/home/evf";
  };

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
