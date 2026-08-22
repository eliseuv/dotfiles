{ pkgs, ... }:
{

  home.packages = with pkgs; [

    # LSP
    yaml-language-server

  ];

}
