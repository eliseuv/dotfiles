{ pkgs, ... }:
{

  imports = [

    # Lua
    ./lua.nix

    # LazyVim
    ./lazyvim.nix

  ];

  programs.neovim = {
    enable = true;
    package = pkgs.neovim;
  };

  home.shellAliases = {
    v = "nvim";
    vr = "nvim -R";
    # From scratch config
    vv = "NVIM_APPNAME=nvim-scratch nvim";
  };

  home.packages = with pkgs; [

    # Clipboard integration
    wl-clipboard

    # Tree-sitter required for :TSInstallFromGrammar
    tree-sitter

  ];

}
