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

  # autoEnable must be set unconditionally: while it is unset, catppuccin/nix
  # (pre-27.05) force-enables itself and warns, which hit non-desktop hosts.
  # `enable` is the global toggle; ports are opted into individually.
  config.catppuccin = {
    enable = config.my.desktop.enable;
    autoEnable = false;
    inherit (config.my.theme) flavor accent;
  };

}
