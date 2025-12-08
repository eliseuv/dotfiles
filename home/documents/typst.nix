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

    # Font Awesome for icons in documents
    font-awesome

  ];

}
