{ ... }:
{

  imports = [

    # Options
    ../modules/dotfiles.nix

    # Shell environment
    ../shell/default.nix

    # Authentication
    ../auth/gpg.nix
    ../auth/ssh.nix

    # Maintenance
    ../maintenance/default.nix

    # Development
    ../development/default.nix

    # Containers
    ../containers/default.nix

    # Text editors (TUI)
    ../editor/neovim/default.nix
    ../editor/helix.nix

    # Services
    ../services/pueue.nix
    ../services/syncthing/default.nix

  ];

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";

}
