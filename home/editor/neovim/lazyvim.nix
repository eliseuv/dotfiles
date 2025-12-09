{ pkgs, lib, ... }:
let
  # lazy.nvim sync script
  lazy-sync = pkgs.writeShellScriptBin "lazy-sync" ''
    ${lib.getExe pkgs.neovim-unwrapped} --headless "+Lazy! sync" +qa && ${pkgs.libnotify}/bin/notify-send "lazy.nvim" "Sync completed" || ${pkgs.libnotify}/bin/notify-send "lazy.nvim" "Sync failed" -u critical
  '';
in
{

  home.packages = with pkgs; [

    # lazy.nvim sync script
    lazy-sync

    # NodeJS required for Copilot
    nodejs

    # LiSt Open Files
    lsof

  ];

  # lazy.nvim sync
  systemd.user.services.lazynvim-sync = {
    Unit = {
      Description = "Sync lazy.nvim packages";
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
      ExecStart = lib.getExe lazy-sync;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # lazy.nvim sync timer
  systemd.user.timers.lazynvim-sync = {
    Unit.Description = "Scheduled lazy.nvim sync";
    Timer = {
      # Run after boot
      OnBootSec = "1m";
      # And periodically while system is running
      OnUnitActiveSec = "6h";
      RandomizedDelaySec = "1m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

}
