{ config, lib, ... }:
{

  config = lib.mkIf config.my.desktop.enable {

    # Default browser
    my.home.defaultApps = lib.genAttrs [
      "x-scheme-handler/http"
      "x-scheme-handler/https"
      "x-scheme-handler/chrome"
      "text/html"
      "application/x-extension-htm"
      "application/x-extension-html"
      "application/x-extension-shtml"
      "application/xhtml+xml"
      "application/x-extension-xhtml"
      "application/x-extension-xht"
    ] (_: [ "firefox.desktop" ]);

  };

}
