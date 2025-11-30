{ pkgs, ... }:
{

  programs.retroarch = {
    enable = true;
    settings = {
      video_driver = "vulkan";
      video_fullscreen = "true";
    };
    cores = {
      # GBA
      mgba.enable = true;
      # NES
      nestopia.enable = true;
      # SNES
      snes9x = {
        enable = true;
        package = pkgs.libretro.snes9x2010;
      };
      # N64
      mupen64plus.enable = true;
    };
  };

}
