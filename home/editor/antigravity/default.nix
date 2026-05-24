{ inputs, ... }:
{

  programs.antigravity = {
    enable = true;
    package = inputs.antigravity-nix.packages.x86_64-linux.default;
  };

}
