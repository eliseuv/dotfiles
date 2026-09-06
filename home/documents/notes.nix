{ ... }:
{

  # Vault-relative paths for the notes vault's vaultmeta tool. Constant across
  # machines (resolved against VAULT_DIR, which is host-specific — see the
  # importing host file). Mirrors notes/.env.example.
  home.sessionVariables = {
    BACKLOG_FILE = "Backlog.md";
    IDEA_DIR = "Idea";
    IDEA_INBOX_FILE = "Idea/Inbox.md";
    LEARNING_DIR = "Learning";
    PROJECT_DIR = "Project";
    TEMPLATES_DIR = "Templates";
    FLAKES_DIR = "Templates/flakes";
    GITIGNORE_DIR = "Templates/gitignore";
    EXTERNAL_INDEX_FILE = "Projects.md";
  };

  # Claude Code skills that operate on the vault (backlog, idea/learning/project
  # workflows). Only relevant on hosts that import this file.
  home.file.".claude/skills" = {
    source = ./notes-skills;
    recursive = true;
  };

}
