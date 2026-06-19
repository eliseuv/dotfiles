{ inputs, pkgs, ... }:
{

  home.packages = [
    inputs.late-sh.packages.${pkgs.stdenv.hostPlatform.system}.late
  ];

}
