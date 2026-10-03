{ lib, pkgs-master, ... }:
let
  # Escape hatch for a release newer than nixpkgs-master. Fill in the version
  # with lib.fakeHash for both hashes, build, and copy each "got:" hash from
  # the mismatch errors (src first, then cargoDeps). Set back to null once
  # nixpkgs-master catches up, or this pin silently holds you back.
  # Releases that bump the rusty_v8 crate also need the librusty_v8 arg
  # overridden; see pkgs/by-name/co/codex/librusty_v8.nix in nixpkgs.
  versionOverride = null;
  # versionOverride = {
  #   version = "0.0.0";
  #   srcHash = lib.fakeHash;
  #   cargoHash = lib.fakeHash;
  # };
in
{

  programs.codex = {
    enable = true;

    # nixos-unstable lags upstream releases for this package; track
    # nixpkgs master instead
    package =
      if versionOverride == null then
        pkgs-master.codex
      else
        pkgs-master.codex.overrideAttrs (
          finalAttrs: prevAttrs: {
            inherit (versionOverride) version;
            src = prevAttrs.src.override {
              tag = "rust-v${finalAttrs.version}";
              hash = versionOverride.srcHash;
            };
            # buildRustPackage reads cargoHash from its original args, not
            # finalAttrs, so overriding cargoHash alone would keep the old
            # vendored deps; cargoDeps has to be rebuilt explicitly
            cargoDeps = pkgs-master.rustPlatform.fetchCargoVendor {
              inherit (finalAttrs) pname version src sourceRoot;
              hash = versionOverride.cargoHash;
            };
          }
        );
  };

}
