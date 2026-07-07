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

    # Host specific
    ../services/syncthing/folders/GLaDOS.nix
    ../desktop/window-manager/hyprland/monitors-GLaDOS.nix

  ];

}
