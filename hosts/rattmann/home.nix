{ ... }:
{

  imports = [

    # Profiles
    ../../home/profiles/core.nix
    ../../home/profiles/gui.nix
    ../../home/profiles/i3.nix

    # Firefox
    ../../home/browser/firefox/default.nix

  ];

}
