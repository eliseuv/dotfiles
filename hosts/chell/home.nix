{ pkgs, ... }:
{

  imports = [

    # Profiles
    ../../home/profiles/core.nix
    ../../home/profiles/gui.nix
    ../../home/profiles/apps.nix
    ../../home/profiles/gaming.nix

    # Firefox (without custom userChrome/tridactyl)
    ../../home/browser/firefox/vanilla.nix

    # Cloud sync
    ../../home/extra/rclone/default.nix

    # Host specific
    ../../home/services/syncthing/folders/chell.nix

  ];

  # Enable terminal decorations (GNOME desktop)
  programs.ghostty.settings.window-decoration = pkgs.lib.mkForce "auto";
  programs.kitty.settings.hide_window_decorations = pkgs.lib.mkForce "no";

}
