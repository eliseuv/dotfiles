{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.apps.enable {

    programs.emacs = {
      enable = true;
      # Prebuilt tree-sitter grammars for Doom's +tree-sitter modules; the
      # wrapper puts them on `treesit-extra-load-path`, so Doom never has to
      # download and compile them into its .local (which `doom sync` can wipe).
      extraPackages = epkgs: [ epkgs.treesit-grammars.with-all-grammars ];
    };

    services.emacs.enable = false;

    home.sessionVariables = {
      EMACS_DIR = "$HOME/.config/emacs";
      DOOM_DIR = "$HOME/.config/doom";
    };

    home.sessionPath = [ "$HOME/.config/emacs/bin" ];

  };

}
