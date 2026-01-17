{ config, ... }:
{

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  environment.etc."hypr/monitors.conf".text =
    if config.networking.hostName == "GLaDOS" then
      ''
        monitor=DP-1,1920x1080@60.0,0x1080,1.0
        monitor=DP-1,transform,1
        monitor=DP-3,2560x1080@74.99,440x0,1.0
        monitor=HDMI-A-1,1920x1080@239.76,1080x1080,1.0
      ''
    else
      ''
        monitor = eDP-1, 1920x1080@60, 0x0, 1
      '';

}
