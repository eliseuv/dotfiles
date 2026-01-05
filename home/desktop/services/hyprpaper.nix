{ ... }:
{

  imports = [ ../wallpapers.nix ];

  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;
      wallpaper = [
        {
          path = "~/.wallpapers/dunes.webp";
          fit_mode = "cover";
        }
      ];
    };
  };

}
