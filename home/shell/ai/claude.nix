{ ... }:
{

  programs.claude-code = {
    enable = true;
  };

  home.file.".claude/CLAUDE.md" = {
    source = ./developer_preferences.md;
    force = true;
  };

  home.shellAliases.a = "claude";

}

