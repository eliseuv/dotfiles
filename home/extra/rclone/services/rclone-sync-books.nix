{
  config,
  pkgs,
  lib,
  ...
}:
let
  # rclone sync books script
  rclone-sync-books = pkgs.writeShellScriptBin "rclone-sync-books" ''
    ${lib.getExe pkgs.rclone} sync \
    /run/media/evf/Storage/Books \
    gdrive:Books \
    --log-level "NOTICE" \
    --log-file=${config.home.homeDirectory}/.rclone-sync.log \
    && ${pkgs.libnotify}/bin/notify-send "rclone" "Books Sync completed" \
    || ${pkgs.libnotify}/bin/notify-send "rclone" "Books Sync failed" -u critical
  '';
  # rclone sync zotero script
  rclone-sync-zotero = pkgs.writeShellScriptBin "rclone-sync-zotero" ''
    ${lib.getExe pkgs.rclone} sync \
    /run/media/evf/Storage/Zotero \
    gdrive:Zotero \
    --log-level "NOTICE" \
    --log-file=${config.home.homeDirectory}/.rclone-sync.log \
    && ${pkgs.libnotify}/bin/notify-send "rclone" "Zotero Sync completed" \
    || ${pkgs.libnotify}/bin/notify-send "rclone" "Zotero Sync failed" -u critical
  '';
in
{

  home.packages = [
    rclone-sync-books
    rclone-sync-zotero
  ];

  # No Install section: the service is only ever started by its timer (or
  # manually), so home-manager switches don't trigger a sync.
  systemd.user.services.rclone-sync-books = {
    Unit = {
      Description = "Rclone Sync Books Service";
      # Skip silently on hosts without the Storage disk
      ConditionPathIsDirectory = "/run/media/evf/Storage/Books";
      Wants = [
        "network.target"
        "nss-lookup.target"
      ];
      After = [
        "network.target"
        "nss-lookup.target"
      ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe rclone-sync-books;
    };
  };

  systemd.user.timers.rclone-sync-books = {
    Unit = {
      Description = "Sync Books to Google Drive every day";
    };
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };

}
