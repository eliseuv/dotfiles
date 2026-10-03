{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.desktop.enable {

    home.packages = with pkgs; [

      # Encryption
      cryptsetup
      veracrypt

      # File manager
      nautilus

      # Calculator
      speedcrunch

    ];

    fonts.fontconfig = {
      enable = true;
    };

  };

}
