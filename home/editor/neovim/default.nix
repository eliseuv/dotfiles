{ pkgs, ... }:
{

  imports = [

    # LazyVim
    ./lazyvim.nix

  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    package = pkgs.neovim;
    withRuby = false;
    withPython3 = false;
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

  ];

}
