{ ... }:
{

  imports = [

    # Profiles
    ../../home/profiles/core.nix
    ../../home/profiles/gui.nix
    ../../home/profiles/apps.nix
    ../../home/profiles/hyprland.nix
    ../../home/profiles/gaming.nix

    # Secrets
    ../../home/auth/password-store.nix
    ../../home/auth/sops.nix

    # Firefox
    ../../home/browser/firefox/default.nix

    # Cloud sync
    ../../home/extra/rclone/default.nix

    # Notes vault
    ../../home/documents/notes.nix

    # Host specific
    ../../home/services/syncthing/folders/GLaDOS.nix
    ../../home/desktop/window-manager/hyprland/monitors-GLaDOS.nix

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
