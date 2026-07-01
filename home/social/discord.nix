{ pkgs, ... }:
{

  home.packages = with pkgs; [

    # Electron client
    (legcord.override { pnpm_10_29_2 = pnpm_10; })

    # TUI client
    discordo

  ];

}
