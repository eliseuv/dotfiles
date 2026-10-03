{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.apps.enable {

    programs.emacs.enable = true;

    services.emacs.enable = false;

    home.sessionVariables = {
      EMACS_DIR = "$HOME/.config/emacs";
      DOOM_DIR = "$HOME/.config/doom";
    };

    home.sessionPath = [ "$HOME/.config/emacs/bin" ];

  };

}
