{ pkgs, ... }:
{

  home.packages = with pkgs; [

    # LSP
    marksman
    # Linter
    markdownlint-cli2
    # Render
    glow

  ];

}
