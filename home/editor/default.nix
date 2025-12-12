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
    ./vscode.nix

  ];

  programs.neovim.defaultEditor = true;

}
