{
  config,
  lib,
  pkgs,
  ...
}:
let
  id = "hyprpaper-wait-for-hyprland";
in
{

  config = lib.mkIf config.my.desktop.hyprland.enable {

    # hyprpaper starts as soon as WAYLAND_DISPLAY is set, which can race
    # Hyprland's own compositor/output setup during login. Block ExecStart
    # until hyprctl can talk to a fully initialized compositor; give up after
    # 15s and start anyway rather than fail the unit.
    systemd.user.services.hyprpaper.Service.ExecStartPre =
      "${pkgs.writeShellScript "wait-for-hyprland-ipc" ''
        for _ in $(seq 1 30); do
          ${lib.getExe' pkgs.hyprland "hyprctl"} monitors >/dev/null 2>&1 && exit 0
          sleep 0.5
        done
        exit 0
      ''}";

    my.patches.${id} = {
      description = ''
        Delays hyprpaper.service until Hyprland answers IPC. Started as soon
        as WAYLAND_DISPLAY is set, hyprpaper found its outputs but never
        rendered the wallpaper on them until the service was restarted
        (seen on GLaDOS).
      '';
      removeWhen = ''
        With the ExecStartPre wait removed, the wallpaper renders at login
        without restarting hyprpaper.service, over a few logins.
      '';
      added = "2026-08-13";
      status = {
        checked = "2026-11-02";
        note = ''
          No upstream report known. Not re-tested without the wait since it
          was added (hyprpaper 0.8.4 in the current lock).
        '';
      };
    };

  };

}
