{ ... }:
{

  # Copy wallpapers
  home.file.".wallpapers" = {
    source = ../../../resources/wallpapers;
    recursive = true;
  };

  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;
      wallpaper = [
        {
          monitor = "";
          path = "~/.wallpapers/dunes.webp";
          fit_mode = "cover";
        }
      ];
    };
  };

}
