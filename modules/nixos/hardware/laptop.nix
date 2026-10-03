{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf (config.my.host.type == "laptop") {

    # Touchpad
    services.libinput.enable = true;

    environment.systemPackages = with pkgs; [

      # Screen brightness control
      brightnessctl

    ];

  };

}
