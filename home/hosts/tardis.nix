{ ... }:
{

  imports = [

    # Profiles
    ../profiles/core.nix
    ../profiles/gui.nix
    ../profiles/apps.nix
    ../profiles/hyprland.nix

    # Secrets
    ../auth/password-store.nix
    ../auth/sops.nix

    # Firefox
    ../browser/firefox/default.nix

    # Notes vault
    ../documents/vaultmeta.nix

    # Host specific
    ../services/syncthing/folders/tardis.nix
    ../desktop/window-manager/hyprland/monitors-tardis.nix

  ];

  home.sessionVariables = {
    VAULT_DIR = "/home/evf/Documents/notes";
    PROJECT_REPOS_DIR = "/home/evf/Projects/project";
    LEARNING_REPOS_DIR = "/home/evf/Projects/learning";
  };

}
