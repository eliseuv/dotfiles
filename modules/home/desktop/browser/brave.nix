{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.desktop.enable {

    home.packages = with pkgs; [ brave ];

  };

}
