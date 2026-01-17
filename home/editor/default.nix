{ ... }:
{

  imports = [

    # TUI
    ./neovim/default.nix
    ./helix.nix

    # GUI
    ./emacs/default.nix
    ./antigravity/default.nix
    ./vscode.nix
    ./zed.nix

  ];

  programs.neovim.defaultEditor = true;

}
