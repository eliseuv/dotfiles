# User-side tooling for the ttyd web terminal; the service itself is
# system/hosts/wheatley/services/ttyd.nix.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    zsh
    lrzsz
    lsix
    libsixel
    openssl
    libwebsockets
    libuv
    nerd-fonts.iosevka-term
  ];

  fonts.fontconfig.enable = true;
}
