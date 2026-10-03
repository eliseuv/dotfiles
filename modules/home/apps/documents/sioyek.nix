{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.apps.enable {

    programs.sioyek = {
      enable = true;
      config = {
        # Use dark mode by default
        "default_dark_mode" = "1";
      };
      bindings = {
        # Scroll screen
        "screen_up" = "<C-p>";
        "screen_down" = "<C-n>";
        # Scroll pages
        "previous_page" = "<C-u>";
        "next_page" = "<C-d>";
        # Zoom
        "fit_to_page_width" = "a";
      };
      package = pkgs.symlinkJoin {
        name = "sioyek";
        paths = [ pkgs.sioyek ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/sioyek \
            --set QT_QPA_PLATFORM xcb
        '';
      };
    };

  };

}
