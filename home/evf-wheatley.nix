{ ... }:
{
  imports = [
    # Shell environment
    ./shell/default.nix

    # Authentication
    # GnuPG
    ./auth/gpg.nix
    # SSH
    ./auth/ssh.nix
    # Standard Unix Password Manager
    ./auth/password-store.nix
    # SOPS
    ./auth/sops.nix

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

    ./extra/ttyd.nix
  ];

  home = {
    username = "evf";
    homeDirectory = "/home/evf";
  };

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
