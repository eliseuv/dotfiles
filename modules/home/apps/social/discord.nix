{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.apps.enable {

    home.packages = with pkgs; [

      # Electron client
      legcord

      # TUI client
      discordo

    ];

  };

}
