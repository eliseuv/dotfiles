{ pkgs, ... }:
{

  home.packages = with pkgs; [
    herdr
  ];

  xdg.configFile."herdr/config.toml".text = ''
    [ui]
    tab_bar_position = "top"
    pane_borders = true
    pane_gaps = false

    [theme]
    name = "catppuccin-mocha"

    [keys]
    prefix = "backtick"
    new_tab = "prefix+c"
    last_pane = "prefix+h"
    previous_tab = "ctrl+shift+h"
    next_tab = "ctrl+shift+l"
    split_vertical = "prefix+l"
    split_horizontal = "prefix+j"
    focus_pane_left = "ctrl+h"
    focus_pane_down = "ctrl+j"
    focus_pane_up = "ctrl+k"
    focus_pane_right = "ctrl+l"
  '';

  home.shellAliases = {
    hr = "herdr";
  };

}
