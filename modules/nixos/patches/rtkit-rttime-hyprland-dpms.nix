{ config, lib, ... }:
let
  id = "rtkit-rttime-hyprland-dpms";
in
{

  config = lib.mkIf config.my.desktop.hyprland.enable {

    # Hyprland takes SCHED_RR through rtkit and sizes its RLIMIT_RTTIME from
    # rtkit's RTTimeUSecMax. The default 200ms hard limit is shorter than an
    # NVIDIA DPMS-off modeset can keep its main thread busy, and crossing it
    # is an uncatchable SIGKILL. The soft limit still drops it out of RT
    # first; the cost is a runaway RT thread (any rtkit client, PipeWire
    # included) holding a core for up to 2s.
    security.rtkit.args = [ "--rttime-usec-max=2000000" ];

    my.patches.${id} = {
      description = ''
        Raises rtkit's realtime CPU budget from 200ms to 2s. Hyprland 0.57's
        SCHED_RR main thread, busy through a DPMS-off modeset on the NVIDIA
        driver (615.78), overran the 200ms RLIMIT_RTTIME hard limit and was
        SIGKILLed: no crash report, no core, every client dropped.
      '';
      removeWhen = ''
        Idle DPMS-off no longer logs "Realtime budget exceeded (SIGXCPU)" from
        Hyprland (journalctl -g 'Realtime budget'), or Hyprland stops
        requesting realtime scheduling through rtkit.
      '';
      added = "2026-11-02";
      status = {
        checked = "2026-11-02";
        note = ''
          Not reported upstream. SIGXCPU logged ~1s after DPMS-off on Nov 1
          21:19 and Nov 2 13:04 (survived); Hyprland killed without a report
          after DPMS-off on Nov 2 12:33 and 12:47 (before the 2s limit).
        '';
      };
    };

  };

}
