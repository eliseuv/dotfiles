{ pkgs, lib, ... }:
{
  # tuiboard isn't packaged in nixpkgs; @opentui/core ships prebuilt
  # per-platform native binaries pulled in at install time, so there's
  # no real payoff in vendoring it through Nix. Reassert the global bun
  # install on every switch instead, so a fresh machine ends up with the
  # same tool without a manual `bun install -g` step. Bump the pinned
  # version below to upgrade.
  home.activation.tuiboard = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.bun}/bin/bun install -g tuiboard@0.13.3
  '';
}
