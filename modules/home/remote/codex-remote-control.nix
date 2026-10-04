# Codex counterpart of claude-remote-control.nix: keeps an app-server with
# remote control enabled running as a user service, so this host is
# reachable from the ChatGPT/Codex apps without a terminal session open.
#
# This runs the same foreground command that `codex remote-control start`
# spawns, rather than going through that managed daemon: the daemon copies
# its own binary into ~/.codex/packages and runs a self-updater, which
# fights the Nix-provided package.
#
# The control socket lives in a private runtime directory instead of
# Codex's default path. Every interactive `codex` TUI silently attaches to
# a server on the default socket, which would make terminal sessions run
# inside this service's environment (no devshell/direnv PATH). To attach
# deliberately: `codex --remote unix://$XDG_RUNTIME_DIR/codex-remote-control/app-server.sock`.
{ config, lib, ... }:
{

  config = lib.mkIf config.my.home.remoteAccess.enable {

    systemd.user.services.codex-remote-control = {
      Unit = {
        Description = "Codex Remote Control app-server";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        WorkingDirectory = "${config.home.homeDirectory}/Projects";
        ExecStart = "${config.programs.codex.package}/bin/codex app-server --remote-control --listen unix://%t/codex-remote-control/app-server.sock";
        RuntimeDirectory = "codex-remote-control";
        RuntimeDirectoryMode = "0700";
        Restart = "always";
        RestartSec = 5;
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

  };

}
