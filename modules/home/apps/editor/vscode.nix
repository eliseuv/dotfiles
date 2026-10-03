{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.apps.enable {

    programs.vscode = {
      enable = true;
      package = pkgs.vscode-fhs;
    };

  };

}
