{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf (config.my.desktop.enable && config.my.desktop.displayManager == "lightdm") {

    services.xserver.displayManager.lightdm = {
      enable = true;
      extraConfig = ''
        [Seat:*]
        greeter-setup-script=${pkgs.numlockx}/bin/numlockx on
      '';
    };

  };

}
