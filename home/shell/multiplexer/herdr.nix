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
    prefix = "grave"
    new_tab = "prefix+c"
    toggle_last_tab = "prefix+h"
    previous_tab = "ctrl+shift+h"
    next_tab = "ctrl+shift+l"
    split_vertical = "prefix+l"
    split_horizontal = "prefix+j"
    move_left = "ctrl+h"
    move_down = "ctrl+j"
    move_up = "ctrl+k"
    move_right = "ctrl+l"
  '';

  home.shellAliases = {
    hr = "herdr";
  };

}
