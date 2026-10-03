{ pkgs, ... }:
{

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
