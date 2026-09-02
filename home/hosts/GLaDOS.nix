{ ... }:
{

  imports = [

    # Profiles
    ../profiles/core.nix
    ../profiles/gui.nix
    ../profiles/apps.nix
    ../profiles/hyprland.nix
    ../profiles/gaming.nix

    # Secrets
    ../auth/password-store.nix
    ../auth/sops.nix

    # Firefox
    ../browser/firefox/default.nix

    # Cloud sync
    ../extra/rclone/default.nix

    # Notes vault
    ../documents/notes.nix

    # Host specific
    ../services/syncthing/folders/GLaDOS.nix
    ../desktop/window-manager/hyprland/monitors-GLaDOS.nix

  ];

  home.sessionVariables =
    let
      notesVault = "/home/evf/Documents/notes";
    in
    {
      NOTES_VAULT = notesVault;
      VAULT_DIR = notesVault;
      PROJECT_REPOS_DIR = "/home/evf/Projects/project";
      LEARNING_REPOS_DIR = "/home/evf/Projects/learning";
    };

}
