{ lib, ... }:
{

  imports = [ ./syncthing.nix ];

  # Enable terminal decorations (GNOME desktop)
  programs.ghostty.settings.window-decoration = lib.mkForce "auto";
  programs.kitty.settings.hide_window_decorations = lib.mkForce "no";

}
