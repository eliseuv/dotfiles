{
  config,
  lib,
  pkgs,
  ...
}:
let
  theme = "rings";
in
{

  config = lib.mkIf config.my.desktop.bootSplash.enable {

    boot = {

      plymouth = {
        enable = true;
        inherit theme;
        themePackages = with pkgs; [
          # By default we would install all themes
          (adi1090x-plymouth-themes.override {
            selected_themes = [ theme ];
          })
        ];
      };

      # Enable "Silent boot"
      consoleLogLevel = 3;
      kernelParams = [
        "quiet"
        "splash"
        "udev.log_priority=3"
        "rd.systemd.show_status=auto"
      ];
      # Hide the OS choice for bootloaders.
      # It's still possible to open the bootloader list by pressing any key
      # It will just not appear on screen unless a key is pressed
      loader.timeout = 0;

    };

  };

}
