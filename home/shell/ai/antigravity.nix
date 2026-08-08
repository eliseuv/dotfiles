{ pkgs, inputs, ... }:
{
  home.packages = with pkgs; [

    antigravity-cli

  ];

  home.file.".gemini/GEMINI.md" = {
    source = ./developer_preferences.md;
    force = true;
  };
}

