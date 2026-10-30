{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
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

  config = lib.mkIf config.my.home.development.enable {

    home.packages = [ ];

  };

}
