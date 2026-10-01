{ lib, pkgs-master, ... }:
let
  # Escape hatch for a release newer than nixpkgs-master: run
  # `just pin-claude-code [version]` and point this at the manifest it writes,
  # e.g. ./claude-code-manifest.json. Set back to null (and delete the file)
  # once nixpkgs-master catches up, or this pin silently holds you back.
  manifestOverride = null;
in
{

  programs.claude-code = {
    enable = true;

    # nixos-unstable lags upstream releases for this package; track
    # nixpkgs master instead
    package =
      if manifestOverride == null then
        pkgs-master.claude-code
      else
        pkgs-master.claude-code.override { manifest = lib.importJSON manifestOverride; };

    # Writes developer_preferences.md to <configDir>/CLAUDE.md
    context = ./developer_preferences.md;
  };

  home.shellAliases.a = "claude";

}
