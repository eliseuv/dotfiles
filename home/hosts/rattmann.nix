{ ... }:
{

  imports = [

    # Profiles
    ../profiles/core.nix
    ../profiles/gui.nix
    ../profiles/i3.nix

    # Firefox
    ../browser/firefox/default.nix

  ];

}
