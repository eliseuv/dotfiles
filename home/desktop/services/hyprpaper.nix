{ pkgs, lib, ... }:
{

  # Copy wallpapers
  home.file.".wallpapers" = {
    source = ../../../resources/wallpapers;
    recursive = true;
  };

  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;
      wallpaper = [
        {
          monitor = "";
          path = "~/.wallpapers/dunes.webp";
          fit_mode = "cover";
        }
      ];
    };
  };

  # hyprpaper starts as soon as WAYLAND_DISPLAY is set, which can race
  # Hyprland's own compositor/output setup during login (seen on GLaDOS:
  # hyprpaper starts and finds its outputs, but never actually renders the
  # wallpaper on them until the service is restarted). Block ExecStart until
  # hyprctl can talk to a fully initialized compositor.
  systemd.user.services.hyprpaper.Service.ExecStartPre =
    "${pkgs.writeShellScript "wait-for-hyprland-ipc" ''
      for _ in $(seq 1 30); do
        ${lib.getExe' pkgs.hyprland "hyprctl"} monitors >/dev/null 2>&1 && exit 0
        sleep 0.5
      done
      exit 0
    ''}";

}
