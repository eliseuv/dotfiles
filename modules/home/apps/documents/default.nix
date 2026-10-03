{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.apps.enable {

    home.sessionVariables.READER = "zathura";

    my.home.defaultApps = {
      "application/pdf" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
      "application/epub+zip" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
    };

  };

}
