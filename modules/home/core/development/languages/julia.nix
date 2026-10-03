{ lib, pkgs, ... }:
let
  # Update environment script
  julia-env-update = pkgs.writeShellScriptBin "julia-env-update" ''
    ${lib.getExe pkgs.julia-bin} --eval "using Pkg; Pkg.add([\"LanguageServer\", \"SymbolServer\"]); Pkg.update()" && ${pkgs.libnotify}/bin/notify-send "Julia" "Environment update completed" || ${pkgs.libnotify}/bin/notify-send "Julia" "Environment update failed" -u critical
  '';
  # Cleanup environment script
  julia-env-gc = pkgs.writeShellScriptBin "julia-env-gc" ''
    ${lib.getExe pkgs.julia-bin} --eval "using Pkg; Pkg.gc()" && ${pkgs.libnotify}/bin/notify-send "Julia" "Environment cleanup completed" || ${pkgs.libnotify}/bin/notify-send "Julia" "Environment cleanup failed" -u critical
  '';
in
{

  home.packages = with pkgs; [
    julia-bin

    # Environment management scripts
    julia-env-update
    julia-env-gc

  ];

  home.file = {
    # REPL startup script
    ".julia/config/startup.jl".source = ./julia/startup.jl;
    # LSP requirements makefile
    ".julia/environments/nvim-lspconfig/Makefile".source = ./julia/Makefile;
    # Pluto notebook templates
    ".julia/pluto_notebooks/ingredients.jl".source = ./julia/ingredients.jl;
  };

  home.sessionVariables = {
    JULIA_NUM_THREADS = "auto";
  };

  home.shellAliases = {
    pluto-run = "julia --eval 'using Pluto; Pluto.run(launch_browser=false)'";
  };

  # Julia environment update
  systemd.user.services.julia-env-update = {
    Unit = {
      Description = "Update Julia environment";
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
      ExecStart = lib.getExe julia-env-update;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.timers.julia-env-update = {
    Unit.Description = "Scheduled Julia environment update";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # Julia environment cleanup
  systemd.user.services.julia-env-gc = {
    Unit = {
      Description = "Cleanup Julia environment";
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe julia-env-gc;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.timers.julia-env-gc = {
    Unit.Description = "Scheduled Julia environment cleanup";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };

}
