{ pkgs, ... }:
{

  home.packages = with pkgs; [

    # Electron client
    legcord

    # TUI client
    discordo

  ];

}
