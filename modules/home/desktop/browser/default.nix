# Browsers other than Firefox (firefox/), which is the default one.
{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.desktop.enable {

    home.packages = with pkgs; [ brave ];

    programs.chromium = {
      enable = true;
      extensions = [
        { id = "ddkjiahejlhfcafbddmgiahcphecmpfh"; } # uBlock Origin Lite
        { id = "pkehgijcmpdhfbdbbnkijodmdjhbjlgp"; } # Privacy Badger
        { id = "mlomiejdfkolichcflejclcbmpeaniij"; } # Ghostery
      ];
      # Chromium's native-Wayland Ozone backend hard-disables Vulkan
      # (ui/ozone/platform/wayland/gpu/wayland_surface_factory.cc), which takes
      # WebGPU down with it. Force X11 (via XWayland) so Vulkan/WebGPU work.
      commandLineArgs = [ "--ozone-platform=x11" ];
    };

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
