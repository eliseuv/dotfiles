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

    # Temporarily disabled: zotero fails to build since nixpkgs dropped
    # firefox-esr-140 (NixOS/nixpkgs#568692). Re-enable once
    # NixOS/nixpkgs#569006 lands in nixos-unstable. Avoid GC until then so the
    # old store path (and its profile compatibility) stays around.
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
