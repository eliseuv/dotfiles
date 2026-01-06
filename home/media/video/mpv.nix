{ pkgs, ... }:
{

  home.packages = with pkgs; [

    # ffmpeg - multimedia framework to decode, encode, transcode, mux, demux, stream, filter and play
    ffmpeg

  ];

  # mpv - versatile media player
  programs.mpv = {
    enable = true;
    bindings = {
      "Alt+=" = "add video-zoom 0.1";
      "Alt+-" = "add video-zoom -0.1";
      "-" = "add volume -2";
      "=" = "add volume 2";
    };
    config = {
      hwdec = "auto";
      ytdl-raw-options = "force-ipv4=";
      screenshot-directory = "~/Pictures/screenshots/";
    };
    scripts = [
      pkgs.mpvScripts.thumbfast
      pkgs.mpvScripts.mpv-playlistmanager
    ];
  };

}
