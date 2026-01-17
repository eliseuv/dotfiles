{ pkgs, lib, ... }:
let
  # Notification sound script
  play-notification-sound = pkgs.writeShellScriptBin "play-notification-sound" ''
    APPNAME="$1"
    if [ "$APPNAME" != "Spotify" ]; then
        ${pkgs.pipewire}/bin/pw-play ~/.local/share/sounds/notification.ogg
    fi
  '';
in
{

  home.packages = with pkgs; [

    # Provides `notify-send`
    libnotify

    # Font
    nerd-fonts.ubuntu

  ];

  services.dunst = {
    enable = true;
    settings = {
      global = {
        monitor = 1;
        origin = "top-center";
        offset = "(0, 5)";
        follow = "keyboard";
        font = "Ubuntu Nerd Font 9";
        width = "(0, 300)";
        frame_width = 2;
        corner_radius = 5;
      };
      urgency_normal = {
        background = "#1e1d2f";
        foreground = "#bd93f9";
        frame_color = "#5e497c";
        timeout = 10;
      };
    };
  };

  # Notification sound
  home.file.".local/share/sounds/notification.ogg".source =
    ../../../resources/sounds/notification.ogg;

}
