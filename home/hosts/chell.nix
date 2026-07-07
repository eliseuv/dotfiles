{ pkgs, ... }:
{

  imports = [

    # Profiles
    ../profiles/core.nix
    ../profiles/gui.nix
    ../profiles/apps.nix
    ../profiles/gaming.nix

    # Firefox (without custom userChrome/tridactyl)
    ../browser/firefox/vanilla.nix

    # Cloud sync
    ../extra/rclone/default.nix

    # Host specific
    ../services/syncthing/folders/chell.nix

  ];

  # The dotfiles repository is shared between users on this machine
  dotfiles.path = "/etc/dotfiles";
  programs.git.settings.safe.directory = [ "/etc/dotfiles" ];

  # Enable terminal decorations (GNOME desktop)
  programs.ghostty.settings.window-decoration = pkgs.lib.mkForce "auto";
  programs.kitty.settings.hide_window_decorations = pkgs.lib.mkForce "no";

}
