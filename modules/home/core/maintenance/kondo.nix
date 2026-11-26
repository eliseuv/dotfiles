{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # PATCH(kondo-nested-projects): built from the fork, which adds --nested.
  # importCargoLock reads the fork's own lockfile, so a `nix flake update
  # kondo` needs no vendor hash bump.
  kondo = pkgs.kondo.overrideAttrs (old: {
    version = "${old.version}-unstable-${inputs.kondo.lastModifiedDate}";
    src = inputs.kondo;
    cargoDeps = pkgs.rustPlatform.importCargoLock {
      lockFile = "${inputs.kondo}/Cargo.lock";
    };
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
      ExecStart = "${lib.getExe kondo} --all --nested --same-filesystem --older 1w $HOME";
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
