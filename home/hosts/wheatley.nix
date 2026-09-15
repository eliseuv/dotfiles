{ ... }:
{

  imports = [

    # Profiles
    ../profiles/core.nix

    # Secrets
    ../auth/password-store.nix
    ../auth/sops.nix

    # Web terminal
    ../extra/ttyd.nix

    # Claude Code Remote Control
    ../extra/claude-remote-control.nix

    # Notes vault
    ../documents/notes.nix

    # Host specific
    ../services/syncthing/folders/wheatley.nix

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
