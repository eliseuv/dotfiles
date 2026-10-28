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

    # Imported from the global CLAUDE.md (developer_preferences.md), so every
    # repo sees the conventions without a per-repo import.
    home.file.".claude/includes/aven-conventions.md".source = ./conventions.md;

    # Imported by learning repos' CLAUDE.md; scaffolded there by the scope skill.
    home.file.".claude/includes/assisted-learning.md".source = ./assisted-learning.md;

    programs = {
      claude-code.skills = workflowSkills;
      codex.skills = workflowSkills;
    };

  };

}
