{ ... }:
{

  imports = [

    # Automount
    ./udiskie.nix


    # Notify time every hour
    ./notify-clock.nix

  ];

}
