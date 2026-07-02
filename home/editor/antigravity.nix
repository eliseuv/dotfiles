{ pkgs, inputs, ... }:
{
  home.packages = with pkgs; [

    inputs.antigravity.packages.${stdenv.hostPlatform.system}.antigravity
    inputs.antigravity.packages.${stdenv.hostPlatform.system}.antigravity-fhs

  ];
}
