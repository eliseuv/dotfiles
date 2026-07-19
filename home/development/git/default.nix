{ ... }:
{

  imports = [

    # Git
    ./git.nix

    # GitHub
    ./github.nix

    # GitLab
    ./gitlab.nix

    # TUI
    ./gitui.nix
    ./lazygit.nix

  ];

  # TUI git tool
  home.shellAliases.gg = "lazygit";

}
