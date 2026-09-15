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

  ];

}
