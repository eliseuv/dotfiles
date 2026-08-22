{ pkgs, ... }:
{

  home.packages = with pkgs; [

    # LSP
    marksman
    # Linter
    markdownlint-cli2
    # Render
    glow

    # Live preview (Doom's markdown +grip flag)
    python3Packages.grip

  ];

}
