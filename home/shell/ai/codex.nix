{ inputs, pkgs, ... }:
{

  programs.codex = {
    enable = true;

    # nixos-unstable lags upstream releases for this package; track
    # nixpkgs master instead
    package =
      (import inputs.nixpkgs-master {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      }).codex;
  };

}
