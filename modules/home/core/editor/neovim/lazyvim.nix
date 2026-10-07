{
  pkgs,
  lib,
  ...
}:
let
  # lazy.nvim sync script
  lazy-sync = pkgs.writeShellScriptBin "lazy-sync" ''
    # Notifications are best-effort: headless hosts have no notification daemon
    if ${lib.getExe pkgs.neovim} --headless "+Lazy! sync" +qa; then
      ${pkgs.libnotify}/bin/notify-send "lazy.nvim" "Sync completed" || true
    else
      ${pkgs.libnotify}/bin/notify-send "lazy.nvim" "Sync failed" -u critical || true
      exit 1
    fi
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

    # Tree-sitter required for :TSInstallFromGrammar
    tree-sitter

  ];

  # Manage init.lua with LazyVim imperatively
  programs.neovim.sideloadInitLua = true;

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
    # Not WantedBy default.target: activation would wait for the sync; the
    # timer's OnBootSec covers the run after login.
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
