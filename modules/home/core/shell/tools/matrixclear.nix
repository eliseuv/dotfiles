# `clear` replacement that pours Matrix-style glyph streams over the screen.
# Options are compile-time constants upstream (config.h), passed as -D flags
# through the package's `defines` argument. The values below are the upstream
# defaults, listed as a template: edit them to taste, or drop any you don't
# need to change.
{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  matrixclear = inputs.matrixclear.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
    defines = [
      # Edges the streams start from
      "DIR_TOP=1"
      "DIR_BOTTOM=0"
      "DIR_LEFT=0"
      "DIR_RIGHT=0"
      # Pick a random combination of edges every run
      "RANDOM_DIRECTIONS=0"

      # Timing: fill, exit, frame rate
      "DURATION_MS=500"
      "EXIT_MS=500"
      "FPS=60"

      # Colours (0xRRGGBB); the head is COLOR whitened unless HEAD_COLOR_AUTO=0
      "COLOR=0x1cff5a"
      "HEAD_COLOR_AUTO=1"
      "HEAD_COLOR=0xffffff"

      # Stream shape and motion
      "TRAIL=10.0f"
      "REST=0.45f"
      "SPEED_SPREAD=3.0f"
      "SPEED=0.0f"
      "STAGGER=0.9f"
      "GLITCH=0.02f"

      # Halfwidth Katakana, digits, and Latin letters
      "MATRIX_GLYPHS=1"

      # COLOR_MODE_AUTO | COLOR_MODE_TRUECOLOR | COLOR_MODE_ANSI256
      "COLOR_MODE=COLOR_MODE_AUTO"
      # Also erase scrollback, like `clear`
      "CLEAR_SCROLLBACK=1"
    ];
  };
in
{

  home.packages = [ matrixclear ];

  # The zsh function previews the prompt while the glyphs exit. Its Ctrl+L
  # widget also restores any command being edited.
  programs.zsh.initContent = ''
    MATRIXCLEAR_BIN=${lib.getExe matrixclear}
    source ${matrixclear}/share/matrixclear/matrixclear.zsh
    alias c=clear
  '';

}
