{ pkgs, ... }:
{

  home.packages = with pkgs; [

    systemctl-tui

  ];

  home.shellAliases.st = "systemctl-tui";

}
