{ ... }:
{

  imports = [

    # Profiles
    ../../home/profiles/core.nix

    # Secrets
    ../../home/auth/password-store.nix
    ../../home/auth/sops.nix

    # Web terminal
    ../../home/extra/ttyd.nix

    # Claude Code Remote Control
    ../../home/extra/claude-remote-control.nix

    # Notes vault
    ../../home/documents/notes.nix

    # Host specific
    ../../home/services/syncthing/folders/wheatley.nix

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
