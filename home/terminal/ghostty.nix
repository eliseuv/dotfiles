{ pkgs, ... }:
{

  home.packages = with pkgs; [ nerd-fonts.iosevka-term ];

  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    installBatSyntax = true;
    installVimSyntax = true;
    settings = {
      theme = "TokyoNight";
      font-family = "IosevkaTerm Nerd Font";
      font-size = 9;
      font-feature = "+calt, +liga, +dlig";
      cursor-style = "block";
      mouse-hide-while-typing = true;
      window-decoration = "none";
      scrollback-limit = 100000000; # ~100mb per terminal
      keybind = [
        # Remove default fullscreen bind
        "ctrl+enter=unbind"
        # Quake-style terminal
        "global:ctrl+backquote=toggle_quick_terminal"
      ];
    };
  };

}
