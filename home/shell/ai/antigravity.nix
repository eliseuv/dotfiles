{ pkgs, inputs, ... }:
{
  home.packages = with pkgs; [

    inputs.antigravity.packages.${stdenv.hostPlatform.system}.antigravity-cli

  ];

  home.file.".gemini/GEMINI.md" = {
    source = ./developer_preferences.md;
    force = true;
  };
}

