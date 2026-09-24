{ inputs, pkgs, ... }:
{

  programs.claude-code = {
    enable = true;

    # nixos-unstable lags upstream releases for this package; track
    # nixpkgs master instead
    package =
      (import inputs.nixpkgs-master {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      }).claude-code;

    # Writes developer_preferences.md to <configDir>/CLAUDE.md
    context = ./developer_preferences.md;
  };

  home.shellAliases.a = "claude";

}
