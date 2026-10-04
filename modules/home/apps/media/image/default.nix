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

      # Ghostscript - ImageMagick shells out to `gs` to rasterize PDFs
      # (needed by snacks.nvim to render math equations)
      ghostscript

      # GIMP - GNU Image Manipulation Program
      gimp

      # Simple X Image Viewer
      sxiv

    ];

    # feh - fast and light image viewer
    programs.feh.enable = true;

    my.home.defaultApps = {
      "image/jpeg" = [ "feh.desktop" ];
      "image/png" = [ "feh.desktop" ];
      "image/*" = [ "sxiv.desktop" ];
      "video/*" = [ "mpv.desktop" ];
    };

  };

}
