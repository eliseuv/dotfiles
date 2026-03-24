{ pkgs, ... }:
{

  programs.password-store = {
    enable = true;
    settings = {
      PASSWORD_STORE_DIR = "$XDG_DATA_HOME/password-store";
    };
  };

  programs.rofi.pass = {
    enable = true;
    package = pkgs.rofi-pass-wayland;
  };

}
