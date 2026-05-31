{ inputs, ... }:
{

  imports = [
    inputs.catppuccin.homeModules.catppuccin
  ];

  catppuccin = {
    enable = true;
    autoEnable = false;
    flavor = "mocha";
    accent = "mauve";
  };

}
