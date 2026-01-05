{ pkgs, ... }:
{

  qt = {
    enable = true;
    style = {
      name = "kvantum";
      package = pkgs.catppuccin-kvantum;
    };
  };

}
