{ ... }:
{

  imports = [

    # Git
    ./git/default.nix

    # Tools
    ./tools/default.nix

    # Languages
    ./languages/nix.nix
    ./languages/c.nix
    ./languages/julia.nix
    ./languages/haskell.nix
    ./languages/python.nix
    ./languages/rust.nix
    ./languages/web.nix
    ./languages/go.nix
    ./languages/zig.nix
    ./languages/uiua.nix

    # Development environments
    ./environment/direnv.nix

  ];

  # Nix Shell
  home.shellAliases = {
    ns = "nix-shell --command zsh --packages";
  };

}
