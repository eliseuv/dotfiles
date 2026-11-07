{
  config,
  lib,
  ...
}:
let
  id = "brave-fullscreen-video-washout";
in
{

  # The fix is the Brave override in modules/home/desktop/browser/default.nix:
  # replacing an element of that home.packages list from here would collide
  # with the unpatched brave.
  config = lib.mkIf config.my.desktop.hyprland.enable {

    my.patches.${id} = {
      description = ''
        Launches Brave with WaylandWpColorManagerV1 disabled. In fullscreen,
        native-Wayland Brave hands video to Hyprland through
        wp_color_management_v1, and Hyprland's conversion washes it out (seen
        with an SDR BT.709 YouTube stream, output in sRGB); windowed, Chromium
        converts it itself and it looks right. Without the protocol Chromium
        also converts fullscreen video, at the cost of HDR passthrough.
      '';
      removeWhen = ''
        Launched without the flag (brave --disable-features=OutdatedBuildDetector,UseChromeOSDirectVideoDecoder),
        a fullscreen YouTube video on Hyprland looks the same as windowed. Also
        drop it if an output is switched to HDR (cm = "hdr"), which the flag
        prevents Brave from using.
      '';
      added = "2026-11-07";
      status = {
        checked = "2026-11-07";
        note = ''
          Reproduced on GLaDOS (Hyprland 0.57.1, Brave 1.98.63 / Chromium 156,
          NVIDIA, Odyssey G40B in sRGB): fullscreen washed out, windowed
          correct; with the flag fullscreen matches windowed. No matching
          Hyprland issue found.
        '';
      };
      locations = [ "modules/home/desktop/browser/default.nix" ];
    };

  };

}
