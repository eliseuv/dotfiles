{ config, lib, ... }:
let
  skillsDirectory = ./notes-skills;
  sharedSkills = lib.mapAttrs (name: _: skillsDirectory + "/${name}") (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsDirectory)
  );
in
{

  config = lib.mkIf config.my.home.notes.enable {

    # NOTES_VAULT is the bootstrap pointer. Skills resolve all other paths with
    # vaultmeta env so a global default cannot override vault .env.
    home.sessionVariables =
      let
        notesVault = "${config.home.homeDirectory}/Documents/notes";
      in
      {
        NOTES_VAULT = notesVault;
        VAULT_DIR = notesVault;
        PROJECT_REPOS_DIR = "${config.home.homeDirectory}/Projects/project";
        LEARNING_REPOS_DIR = "${config.home.homeDirectory}/Projects/learning";
      };

    home.shellAliases = {
      n = "cd $NOTES_VAULT && shoin Goals.md";
    };

    # Personal skills that operate on graduated learning/project repos (outside
    # the vault). Declare them as an attribute set so other modules can add
    # skills through the same options. Vault-specific skills remain local to the
    # vault.
    programs = {
      claude-code.skills = sharedSkills;
      codex.skills = sharedSkills;
    };

  };

}
