{ lib, ... }:
let
  skillsDirectory = ./notes-skills;
  sharedSkills = lib.mapAttrs (
    name: _: skillsDirectory + "/${name}"
  ) (lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsDirectory));
in
{

  # Vault-relative path needed outside the vault directory: project-review (a
  # graduated-repo skill, so it can run from inside any repo, not the vault)
  # interpolates $TEMPLATES_DIR directly in a shell command. Every other
  # vault-relative path lives only in notes/.env now — vault-local skills
  # resolve them through `vaultmeta.py path`, never as raw env vars, so they
  # don't need to be global. Constant across machines (resolved against
  # VAULT_DIR, which is host-specific — see the importing host file).
  home.sessionVariables = {
    TEMPLATES_DIR = "Templates";
  };

  # Personal skills that operate on graduated learning/project repos (outside
  # the vault). Declare them as an attribute set so other modules can add
  # skills through the same options. Vault-specific skills remain local to the
  # vault.
  programs = {
    claude-code.skills = sharedSkills;
    codex.skills = sharedSkills;
  };

}
