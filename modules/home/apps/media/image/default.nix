{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.apps.enable {

    home.packages = with pkgs; [

      # ImageMagick - image manipulation tool
      imagemagick

      # GIMP - GNU Image Manipulation Program
      gimp

    ];

    xdg.mimeApps = {
      enable = true;
      associations.added = {
        "image/jpeg" = [ "feh.desktop" ];
        "image/png" = [ "feh.desktop" ];
        "image/*" = [ "sxiv.desktop" ];
        "video/*" = [ "mpv.desktop" ];
      };
      defaultApplications = {
        "image/jpeg" = [ "feh.desktop" ];
        "image/png" = [ "feh.desktop" ];
        "image/*" = [ "sxiv.desktop" ];
        "video/*" = [ "mpv.desktop" ];
      };
    };

  };

}
