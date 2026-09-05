{ ... }:
{

  programs.claude-code = {
    enable = true;

    # Writes developer_preferences.md to <configDir>/CLAUDE.md
    context = ./developer_preferences.md;
  };

  home.shellAliases.a = "claude";

}
