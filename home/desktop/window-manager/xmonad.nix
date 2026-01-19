{ pkgs, ... }:
{

  home.packages = with pkgs; [
    # Audio mixer
    pulsemixer
  ];

  xsession.windowManager.xmonad = {
    enable = true;
    enableContribAndExtras = true;
    config = ./xmonad/xmonad.hs;
    libFiles = {
      "Colors/DoomOne.hs" = ./xmonad/lib/Colors/DoomOne.hs;
    };
  };

  # feh wallpaper
  home.file.".xmonad/.fehbg".source = ./xmonad/.fehbg;

  # Hide mouse
  services.unclutter.enable = true;

}
