{ inputs, ... }:
{

  home.packages = [

    inputs.antigravity-nix.packages.x86_64-linux.default

  ];

}
