{ pkgs, ... }:
{

  home.packages = with pkgs; [

    typst

    # LSP
    tinymist

    # Formatter
    typstyle
    prettypst

    # Packager manager
    utpm

  ];

}
