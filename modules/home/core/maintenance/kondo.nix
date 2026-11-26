{ pkgs, lib, ... }:
let
  # PATCH(kondo-nested-projects): adds --nested
  kondo = pkgs.kondo.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../../patches/kondo-nested-projects.patch ];
  });
in
{

  home.packages = [ kondo ];

  systemd.user.services.kondo-clean = {
    Unit = {
      Description = "Cleans older project files";
    };
    Service = {
      Type = "oneshot";
      # PATCH(kondo-nested-projects): --nested
      ExecStart = "${lib.getExe kondo} --all --nested --follow-symlinks --same-filesystem --older 1w $HOME";
    };
    # Not WantedBy default.target: a full $HOME scan would block activation;
    # the timer runs it instead.
  };

  systemd.user.timers.kondo-clean = {
    Unit.Description = "Scheduled kondo cleaning";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };

}
