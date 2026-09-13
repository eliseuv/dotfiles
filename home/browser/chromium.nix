{ ... }:
{

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

}
