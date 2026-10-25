# Agent multiplexer, installed for evf only: modules/home applies to every
# user of a host, and dani does not use it.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Generated from the binary so the skill and the integration hooks always
  # match the installed CLI (its own description says the binary is the
  # authority on syntax). The installer refuses to run without the agent's
  # config directory, hence the mkdir. The hooks shell out to python3 and
  # silently no-op without it, so PATH is pinned rather than inherited.
  generated =
    pkgs.runCommand "herdr-generated"
      {
        nativeBuildInputs = [ pkgs.herdr ];
      }
      ''
        export HOME=$TMPDIR/home
        mkdir -p $HOME/.claude $HOME/.codex $out/skill

        herdr --skill > $out/skill/SKILL.md
        herdr integration install claude
        herdr integration install codex

        for hook in $HOME/.claude/hooks/herdr-agent-state.sh $HOME/.codex/herdr-agent-state.sh; do
          sed -i '/^set -eu$/a export PATH=${pkgs.python3}/bin:"$PATH"' "$hook"
        done
        cp $HOME/.claude/hooks/herdr-agent-state.sh $out/claude.sh
        cp $HOME/.codex/herdr-agent-state.sh $out/codex.sh
      '';

  mauve = {
    latte = "#8839ef";
    frappe = "#ca9ee6";
    macchiato = "#c6a0f6";
    mocha = "#cba6f7";
  };

  hookCommand = script: "bash '${script}' session";
  claudeHookScript = "${config.home.homeDirectory}/.claude/hooks/herdr-agent-state.sh";
  codexHookScript = "${config.home.homeDirectory}/.codex/herdr-agent-state.sh";
in
{

  config = lib.mkIf (config.home.username == "evf") {
    programs.herdr = {
      enable = true;
      # Herdr's settings screen writes config.toml itself.
      mutableSettings = true;
      # Herdr only ships mocha ("catppuccin") and latte; frappe and macchiato
      # fall back to mocha.
      settings.ui = {
        # Mirrors the tmux/zellij status bar: on top, hostname and clock at
        # the right.
        tab_bar_position = "top";
        tab_bar_right = [
          { type = "hostname"; }
          {
            type = "datetime";
            format = "%Y-%m-%d %H:%M";
          }
        ];
        # Herdr takes a hex accent, not a Catppuccin name, so only mauve (the
        # shared default) is mapped.
        accent = lib.mkIf (config.my.theme.accent == "mauve") mauve.${config.my.theme.flavor};
      };
      settings.theme.name = if config.my.theme.flavor == "latte" then "catppuccin-latte" else "catppuccin";
    };
    home.shellAliases.h = "herdr";

    programs.claude-code = {
      skills.herdr = "${generated}/skill";
      hooks."herdr-agent-state.sh" = "${generated}/claude.sh";
      # Claude Code rewrites settings.json itself (/config, theme), so merge
      # the declared keys into a writable file instead of owning it outright.
      mutableSettings = true;
      settings.hooks.SessionStart = [
        {
          matcher = "^(startup|resume|clear|compact|fork)$";
          hooks = [
            {
              type = "command";
              command = hookCommand claudeHookScript;
              timeout = 10;
            }
          ];
        }
      ];
    };

    programs.codex = {
      skills.herdr = "${generated}/skill";
      mutableSettings = true;
      settings.features.hooks = true;
      hooks.SessionStart = [
        {
          hooks = [
            {
              type = "command";
              command = hookCommand codexHookScript;
              timeout = 10;
            }
          ];
        }
      ];
    };

    home.file.".codex/herdr-agent-state.sh" = {
      source = "${generated}/codex.sh";
      executable = true;
    };
  };

}
