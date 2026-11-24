{ pkgs, ... }:
{

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withRuby = false;
    withPython3 = false;
  };

  home.shellAliases = {
    v = "nvim";
    vr = "nvim -R";
    # From scratch config
    vv = "NVIM_APPNAME=nvim-scratch nvim";
  };
  my.home.nuCommands.vv = ''
    def --wrapped vv [...args] { NVIM_APPNAME=nvim-scratch ^nvim ...$args }
  '';

  home.packages = with pkgs; [

    # Clipboard integration
    wl-clipboard

  ];

}
