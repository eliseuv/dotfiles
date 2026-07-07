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

    # Host specific
    ../services/syncthing/folders/tardis.nix
    ../desktop/window-manager/hyprland/monitors-tardis.nix

  ];

}
