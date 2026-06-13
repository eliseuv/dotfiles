{ inputs, pkgs, ... }:
{

  home.packages = [
    inputs.late-sh.packages.${pkgs.system}.late
  ];

}
