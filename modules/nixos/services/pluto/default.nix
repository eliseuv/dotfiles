# Pluto notebook server running as the primary user, started on demand: by
# `pluto-connect` (home julia.nix), from the dashboard's Pluto tiles, or by
# hand. A system unit rather than a home-manager user service so svcctl and
# the remote-control login can start it through polkit, like ttyd.
#
# The secret is a sops secret rather than Pluto's per-run one, so the
# dashboard's nginx can hand it to Pluto as a cookie (hosts/wheatley/services/
# pluto.nix) and `pluto-url` can print a working link for tunnels.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.services.pluto;
  user = config.my.host.primaryUser;
  unit = "pluto.service";
  secret = config.sops.secrets."pluto/secret".path;
  # Where to reach Pluto from this host
  localAddress = if cfg.bindAddress == "0.0.0.0" then "127.0.0.1" else cfg.bindAddress;
  # The first start precompiles Pluto, which can take minutes
  startTimeoutSec = 300;

  # Holds `systemctl start pluto` until Pluto answers, so callers can use it
  # as soon as the start returns. Not /ping: under a base path Pluto wants the
  # secret for it too, and logs the secret on every unauthenticated request.
  waitReady = pkgs.writeShellScript "pluto-wait-ready" ''
    for _ in $(seq ${toString startTimeoutSec}); do
      ${lib.getExe pkgs.curl} -sf -o /dev/null -b "secret=$(cat ${secret})" http://${localAddress}:${toString cfg.port}${cfg.basePath} && exit 0
      sleep 1
    done
    exit 1
  '';

  # The URL with its secret, for pluto-connect's tunnel (same local port).
  plutoUrl = pkgs.writeShellScriptBin "pluto-url" ''
    printf 'http://localhost:%s%s?secret=%s\n' ${toString cfg.port} ${lib.escapeShellArg cfg.basePath} "$(cat ${secret})"
  '';
in
{

  config = lib.mkIf cfg.enable {

    assertions = [
      {
        assertion = config.my.secrets.system.enable;
        message = "my.services.pluto needs my.secrets.system.enable for its pluto/secret";
      }
      {
        assertion = lib.hasPrefix "/" cfg.basePath && lib.hasSuffix "/" cfg.basePath;
        message = "my.services.pluto.basePath must start and end with /";
      }
    ];

    sops.secrets."pluto/secret".owner = user;

    environment.systemPackages = [ plutoUrl ];

    # No wantedBy: started on demand.
    systemd.services.pluto = {
      description = "Pluto notebook server";
      after = [ "network.target" ];
      serviceConfig = {
        User = user;
        Group = "users";
        # Pluto's file picker is relative to the working directory
        WorkingDirectory = config.users.users.${user}.home;
        # Login shell for the same environment as an SSH session: julia and
        # Pluto come from the user's home-manager profile and ~/.julia.
        ExecStart = "${pkgs.zsh}/bin/zsh -lc ${
          lib.escapeShellArg (
            lib.escapeShellArgs [
              "exec"
              "julia"
              "${./server.jl}"
              cfg.bindAddress
              (toString cfg.port)
              cfg.basePath
              secret
            ]
          )
        }";
        ExecStartPost = "${waitReady}";
        TimeoutStartSec = startTimeoutSec + 30;
        Restart = "on-failure";
      };
    };

    # The primary user (pluto-connect) can start and stop it without sudo.
    security.polkit.extraConfig = ''
      polkit.addRule(function (action, subject) {
        if (
          action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.user == "${user}" &&
          action.lookup("unit") == "${unit}" &&
          ["start", "stop", "restart"].indexOf(action.lookup("verb")) >= 0
        ) {
          return polkit.Result.YES;
        }
      });
    '';

  };

}
