{
  config,
  inputs,
  lib,
  ...
}:
{

  imports = [
    inputs.catppuccin.homeModules.catppuccin
  ];

  config = lib.mkIf config.my.desktop.enable {

    catppuccin = {
      enable = true;
      autoEnable = false;
      inherit (config.my.theme) flavor accent;
    };

  };

}
