{ pkgs, ... }:
{

  imports = [

    # Pandoc
    ./pandoc.nix

    # PDF viewer
    ./zathura.nix
    ./sioyek.nix

    # Ebooks
    ./calibre.nix

    # Papers
    ./zotero.nix

    # Typesetting
    ./latex.nix
    ./typst.nix
    ./markdown.nix

    # Notes
    ./obsidian.nix

  ];

  home.sessionVariables.READER = "zathura";

  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "application/pdf" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
      "application/epub+zip" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
    };
    defaultApplications = {
      "application/pdf" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
      "application/epub+zip" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
    };
  };

}
