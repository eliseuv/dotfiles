{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.apps.enable {

    home.packages = with pkgs; [

      sniffnet

      # dependencies
      libpcap
      alsa-lib
      fontconfig
      gtk3

    ];

  };

}
