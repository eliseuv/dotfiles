{ pkgs, ... }:
{

  home.packages = with pkgs; [ tldr ];

  home.shellAliases.tldrf = ''
    tldr --list | tr -d "[''']," | tr ' ' '
        ' | fzf --preview "tldr {1}" --preview-window=right,70% | xargs tldr'';

}
