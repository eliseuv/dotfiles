{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.apps.enable {

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

  };

}
