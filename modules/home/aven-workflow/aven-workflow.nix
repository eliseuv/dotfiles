# The agent-facing layer on top of aven: the shared conventions every session
# imports, and the checker that enforces them. Follows programs.aven.enable so
# it only exists where aven does.
{ config, lib, pkgs, ... }:
let
  avenLint = pkgs.writers.writePython3Bin "aven-lint" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./aven-lint.py);

  skillsDirectory = ./skills;
  workflowSkills = lib.mapAttrs (name: _: skillsDirectory + "/${name}") (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsDirectory)
  );
in
{

  config = lib.mkIf config.programs.aven.enable {

    home.packages = [ avenLint ];

    # Both agents load the same conventions globally, including remote sessions.
    # Codex does not expand Claude-style @ imports.
    home.file.".claude/includes/aven-conventions.md".source = ./conventions.md;

    # Imported by learning repos' CLAUDE.md; scaffolded there by the scope skill.
    home.file.".claude/includes/assisted-learning.md".source = ./assisted-learning.md;

    programs = {
      claude-code.skills = workflowSkills;
      codex.skills = workflowSkills;
      codex.context = ./conventions.md;
      codex.settings.sandbox_workspace_write.writable_roots = [
        "${config.home.homeDirectory}/Projects"
        "${config.home.homeDirectory}/dotfiles"
        "${config.xdg.stateHome}/aven"
        "${config.xdg.configHome}/aven"
        "${config.home.homeDirectory}/Documents/ideas"
      ];

      # Global exec policy: matching commands run without a prompt and outside
      # the sandbox, which would otherwise block aven's database under
      # ~/.local/state/aven. Deleting stays manual; the strictest decision wins.
      codex.rules.aven = ''
        prefix_rule(
          pattern = ["aven"],
          decision = "allow",
          justification = "Local aven task manager, driven by the workflow skills.",
          match = ["aven list", "aven note T-1 text"],
        )
        prefix_rule(
          pattern = ["aven-lint"],
          decision = "allow",
          justification = "Read-only structure checker for aven projects.",
          match = ["aven-lint --project demo"],
        )
        prefix_rule(
          pattern = ["aven", "delete"],
          decision = "forbidden",
          justification = "Task deletion is a manual act.",
          match = ["aven delete T-1"],
          not_match = ["aven list"],
        )
      '';
    };

  };

}
