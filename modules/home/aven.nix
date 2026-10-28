# Installed for evf only: modules/home applies to every user of a host, and
# dani does not use it.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.aven;
  yaml = pkgs.formats.yaml { };
  configFile = "${config.xdg.configHome}/aven/config.yaml";
in
{

  options.programs.aven = {
    enable = lib.mkEnableOption "the aven task manager";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.aven.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "The aven package, built from the upstream flake.";
    };

    settings = lib.mkOption {
      type = yaml.type;
      default = { };
      description = ''
        Contents of aven's config.yaml (see aven's configuration docs). Merged
        over the existing file at activation rather than symlinked, because
        `aven config set` rewrites it in place. Keep secrets out: this ends up
        in the Nix store.
      '';
    };

    daemon.enable = lib.mkEnableOption "the background sync daemon" // {
      default = true;
    };
  };

  config = lib.mkMerge [
    {
      programs.aven.enable = lib.mkDefault (
        config.my.home.aven.enable && config.home.username == "evf"
      );
    }

    (lib.mkIf cfg.enable {
      home.packages = [ cfg.package ];

      # Declared here instead of `aven daemon install`, which records the
      # running binary's store path and goes stale on the next upgrade. An
      # upgrade changes this unit instead, so the switch restarts it. Until the
      # database is set up or joined the daemon waits without contacting a
      # server, so it is safe on a device that does not sync yet.
      programs.aven.settings.sync.enabled = lib.mkIf cfg.daemon.enable (lib.mkDefault true);
      systemd.user.services.aven-daemon = lib.mkIf cfg.daemon.enable {
        Unit.Description = "Aven background sync";
        Service = {
          ExecStart = "${lib.getExe' cfg.package "aven"} daemon";
          Restart = "always";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };

      # Updates come from the flake input, not aven's own check.
      programs.aven.settings.update.automatic_checks = lib.mkDefault false;

      # Declared keys win on every switch; keys set only through `aven config
      # set` survive. A leftover read-only symlink is replaced by a real file
      # first so the merge result stays writable.
      home.activation.avenConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        config_file=${lib.escapeShellArg configFile}
        run mkdir -p "$(dirname "$config_file")"
        if [ -L "$config_file" ]; then
          run cp --remove-destination "$(readlink -f "$config_file")" "$config_file"
          run chmod u+w "$config_file"
        fi
        [ -e "$config_file" ] || run touch "$config_file"
        run ${lib.getExe pkgs.yq-go} eval-all --inplace \
          'select(fileIndex == 0) * select(fileIndex == 1)' \
          "$config_file" ${yaml.generate "aven-config.yaml" cfg.settings}
      '';
    })
  ];

}
