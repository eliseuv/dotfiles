{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.apps.enable {

    home.packages = with pkgs; [

      # Notes
      obsidian

    ];

    # PATCH(zotero-firefox-esr): zotero disabled; see PATCHES.md.
    # home.packages = with pkgs; [ zotero ];

    programs = {

      # Document conversion
      pandoc.enable = true;

      # Ebooks
      calibre.enable = true;

      # PDF viewer
      zathura = {
        enable = true;
        mappings = {
          "<C-i>" = "recolor";
        };
        options = {
          recolor = true;
        };
      };

    };

    home.sessionVariables.READER = "zathura";

    my.home.defaultApps = {
      "application/pdf" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
      "application/epub+zip" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
    };

  };

}
