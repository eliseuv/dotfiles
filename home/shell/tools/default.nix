{ pkgs, ... }:
{

  imports = [
    # cd
    ./zoxide.nix
    # ls
    ./eza.nix
    # cat
    ./bat.nix
    # find
    ./fd.nix
    # grep
    ./ripgrep.nix
    # Fuzzy finder
    ./television.nix
    ./fzf.nix
    # File manager
    ./broot.nix
    ./yazi.nix
    # System monitor
    ./bottom.nix
    # Monitor file changes
    ./viddy.nix
    # Systemctl TUI
    ./systemctl-tui.nix
    # Reverse Engineering
    ./rizin.nix
  ];

  home.packages = with pkgs; [

    # Stream editor
    sd

    # Disk usage analyzer
    dua

    # File change monitor
    hwatch

    # Duplicate file finder
    fdupes

    # TUI process runner
    mprocs

    # wget
    wget

  ];

}
