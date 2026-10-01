{ pkgs, inputs, ... }:

let
  # Each source comes from a flake input (flake = false) pinned in flake.lock;
  # bump with `nix flake lock --update-input <name>-src`.

  shoin = pkgs.rustPlatform.buildRustPackage {
    pname = "shoin";
    version = "0.1.5";
    src = inputs.shoin-src;
    cargoLock.lockFile = "${inputs.shoin-src}/Cargo.lock";
  };

  # Excluded:
  # - late-cli (github:mpiorowski/late-sh, late-cli member): transitively
  #   depends on webrtc-sys, whose build.rs downloads a prebuilt WebRTC
  #   binary from the network, incompatible with the Nix sandbox. Fixable
  #   via LK_CUSTOM_WEBRTC + a pinned fetchurl of the release zip, but not
  #   done here.
  # - ytui-music (github:sudipghimire533/ytui-music, front-end member):
  #   fails to compile against current rustc
  #   (deny(dangerous_implicit_autorefs) in front-end/src/ui/mod.rs), an
  #   upstream issue unrelated to packaging. Re-add once fixed upstream.
in

{

  home.packages = [
    shoin
  ];

}
