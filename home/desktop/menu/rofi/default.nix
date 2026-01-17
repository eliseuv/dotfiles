{ pkgs, ... }:
{

  home.packages = with pkgs; [
    # Fonts
    iosevka
    nerd-fonts.iosevka
  ];

  programs.rofi = {
    enable = true;
    package = pkgs.rofi-unwrapped;
    # theme = "tokyonight";
    # font = "Hack Nerd Font 12";
    # cycle = true;
    # terminal = "ghostty";
    # extraConfig = {
    #   modi = "combi";
    #   combi-modi = "drun";
    #   kb-remove-char-forward = "Delete";
    #   kb-remove-char-back = "BackSpace,Shift+BackSpace";
    #   kb-remove-to-eol = "Control+d";
    #   kb-accept-entry = "Control+m,Return,KP_Enter";
    #   kb-mode-complete = "Control+l";
    #   kb-row-left = "Control+h";
    #   kb-row-up = "Up,Control+k,Control+p";
    #   kb-row-down = "Down,Control+j,Control+n";
    # };
  };

  # Use deathemonic's config
  home.file.".config/rofi" = {
    source = ./deathemonic;
    recursive = true;
  };

  # # Copy themes
  # home.file = {
  #   ".config/rofi/themes" = {
  #     source = ./themes;
  #     recursive = true;
  #   };
  # };

}
