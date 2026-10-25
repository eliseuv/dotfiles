# Agent multiplexer, installed for evf only: modules/home applies to every
# user of a host, and dani does not use it.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Generated from the binary so the skill always matches the installed CLI
  # (its own description says the binary is the authority on syntax).
  skill = pkgs.runCommand "herdr-skill" { } ''
    mkdir $out
    ${lib.getExe pkgs.herdr} --skill > $out/SKILL.md
  '';
in
{

  config = lib.mkIf (config.home.username == "evf") {
    home.packages = [ pkgs.herdr ];
    home.shellAliases.h = "herdr";

    programs.claude-code.skills.herdr = skill;
    programs.codex.skills.herdr = skill;
  };

}
