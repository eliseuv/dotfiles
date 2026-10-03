# User-side tooling for the ttyd web terminal; the service itself is
# hosts/wheatley/services/ttyd.nix.
{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.remoteAccess.enable {

    home.packages = with pkgs; [
      zsh
      lrzsz
      lsix
      libsixel
      openssl
      libwebsockets
      libuv
      config.my.theme.monoFont.package
    ];

    fonts.fontconfig.enable = true;

  };

}
