# Runs `claude remote-control` as an always-on user service, so this host
# is reachable from claude.ai/code or the Claude mobile app without a
# terminal session open. Same-dir spawn mode (the default): every session
# — the pre-created one and any spawned on demand — shares the working
# directory below rather than getting its own git worktree.
#
# The home directory itself can't be used: Claude Code never persists
# workspace trust for $HOME, so a session started there fails every
# launch. `~/Projects` is a dedicated, otherwise-empty directory instead,
# with `~/dotfiles` and `~/Services` granted as additional accessible
# directories (see `home/extra/`'s other services) so sessions here can
# still reach the config and the deployed services.
#
# Workspace trust for `~/Projects` was accepted once by hand (there's no
# non-interactive way to answer that dialog). Separately, the command
# itself asks "Enable Remote Control? (y/n)" on every launch; StandardInput
# below answers that so the service doesn't need a real terminal to start.
{ config, ... }:
let
  projectsDir = "${config.home.homeDirectory}/Projects";
in
{

  home.file."Projects/.claude/settings.json".text = builtins.toJSON {
    permissions.additionalDirectories = [
      "${config.home.homeDirectory}/dotfiles"
      "${config.home.homeDirectory}/Services"
    ];
  };

  systemd.user.services.claude-remote-control = {
    Unit = {
      Description = "Claude Code Remote Control server";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      WorkingDirectory = projectsDir;
      ExecStart = "${config.programs.claude-code.finalPackage}/bin/claude remote-control";
      StandardInput = "data";
      StandardInputText = "y\n";
      Restart = "always";
      RestartSec = 5;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

}
