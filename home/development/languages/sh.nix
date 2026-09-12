{ pkgs, ... }:
{

  home.packages = with pkgs; [

    # Formatter
    shfmt

    # Linter
    shellcheck

  ];

}
