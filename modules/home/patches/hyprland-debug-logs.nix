{ config, lib, ... }:
let
  id = "hyprland-debug-logs";
in
{

  config = lib.mkIf config.my.desktop.hyprland.enable {

    # Hyprland's own logging is off by default, leaving only aquamarine trace
    # in hyprland.log; an exit that bypasses the crash reporter (no report,
    # no core) is otherwise undiagnosable.
    wayland.windowManager.hyprland.settings.config.debug.disable_logs = false;

    my.patches.${id} = {
      description = ''
        Enables Hyprland's own debug log while the DPMS-off kill
        (rtkit-rttime-hyprland-dpms) is unresolved. Diagnostic only; the log
        lives on tmpfs (/run/user) and grows quickly.
      '';
      removeWhen = ''
        rtkit-rttime-hyprland-dpms is removed, or the DPMS-off kill is
        diagnosed and no longer needs the log.
      '';
      added = "2026-11-02";
      status = {
        checked = "2026-11-27";
        note = ''
          Hyprland 0.57.2 no longer requests realtime scheduling (see
          rtkit-rttime-hyprland-dpms), the path suspected in the kill. Removal
          of both awaits confirmation. The log was 1.2 MB after under an hour
          of this session.
        '';
      };
    };

  };

}
