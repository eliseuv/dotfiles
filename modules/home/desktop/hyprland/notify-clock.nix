{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.desktop.hyprland.enable {

    systemd.user.services.notify-clock = {
      Unit = {
        Description = "Send time as notification";
      };
      Service = {
        ExecStart = pkgs.writeShellScript "notify-clock.sh" ''
          ${pkgs.libnotify}/bin/notify-send "  $(date +%R)"
        '';
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.timers.notify-clock = {
      Unit.Description = "Notify time every hour";
      Timer = {
        OnCalendar = "hourly";
      };
      Install.WantedBy = [ "timers.target" ];
    };

  };

}
