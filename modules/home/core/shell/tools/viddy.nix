{ pkgs, ... }:
{

  home.packages = with pkgs; [

    viddy

  ];

  home.shellAliases = {
    w = "viddy ";
  };

}
