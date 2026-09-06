{ ... }:
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

  # Claude Code skills that operate on graduated learning/project repos (outside
  # the vault). Vault-specific skills live in the vault's own .claude/skills
  # instead, since they're only useful there. Only relevant on hosts that
  # import this file.
  home.file.".claude/skills" = {
    source = ./notes-skills;
    recursive = true;
  };

}
