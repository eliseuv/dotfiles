{ pkgs, lib, ... }:
{

  home.packages = with pkgs; [ kondo ];

  systemd.user.services.kondo-clean = {
    Unit = {
      Description = "Cleans older project files";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe pkgs.kondo} --all --follow-symlinks --same-filesystem --older 1w $HOME";
    };
    Install.WantedBy = [ "default.target" ];
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
