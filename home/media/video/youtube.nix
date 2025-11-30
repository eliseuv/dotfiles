{ pkgs, inputs, ... }:
{

  home.packages = with pkgs; [

    # ffmpeg - multimedia framework to decode, encode, transcode, mux, demux, stream, filter and play
    ffmpeg

    # yt-x: YouTube TUI client
    inputs.yt-x.packages."${stdenv.hostPlatform.system}".default

  ];

  # yt-dlp - A youtube-dl fork with additional features and fixes
  programs.yt-dlp = {
    enable = true;
  };

}
