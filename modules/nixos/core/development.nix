{ pkgs, ... }:
{

  environment.systemPackages = with pkgs; [

    # Compilers
    clang
    gcc
    gfortran

  ];

}
