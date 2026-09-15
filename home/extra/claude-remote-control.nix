# Runs `claude remote-control` as an always-on user service, so this host
# is reachable from claude.ai/code or the Claude mobile app without a
# terminal session open. Same-dir spawn mode (the default): every session
# — the pre-created one and any spawned on demand — shares
# `config.home.homeDirectory` rather than getting its own git worktree.
{ config, ... }:
{

  systemd.user.services.claude-remote-control = {
    Unit = {
      Description = "Claude Code Remote Control server";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      WorkingDirectory = config.home.homeDirectory;
      ExecStart = "${config.programs.claude-code.finalPackage}/bin/claude remote-control";
      Restart = "always";
      RestartSec = 5;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

}
