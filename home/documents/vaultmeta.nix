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
    FLAKES_DIR = "flakes";
    GITIGNORE_DIR = "gitignore";
    EXTERNAL_INDEX_FILE = "external-projects.md";
  };

}
