{ ... }:
{

  imports = [

    # TUI
    ./neovim/default.nix
    ./helix.nix

    # GUI
    ./emacs/default.nix
    ./zed.nix
    ./antigravity.nix

  ];

  programs.neovim.defaultEditor = true;

  home.sessionVariables = {
    VISUAL = "emacsclient -c -a emacs";
  };

}
