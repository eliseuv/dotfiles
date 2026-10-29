# `clear` replacement that pours braille glyph streams over the screen.
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

      # Timing: time until all streams meet, fade length, fade steps, frame rate
      "DURATION_MS=900"
      "FADE_MS=350"
      "FADE_STEPS=10"
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

      # Glyph code-point range (braille)
      "CHARS_LO=0x2800"
      "CHARS_HI=0x28FF"

      # COLOR_MODE_AUTO | COLOR_MODE_TRUECOLOR | COLOR_MODE_ANSI256
      "COLOR_MODE=COLOR_MODE_AUTO"
      # Also erase scrollback, like `clear`
      "CLEAR_SCROLLBACK=1"
    ];
  };
in
{

  home.packages = [ matrixclear ];

  # Ctrl+L as a zle widget instead of an alias, so the line being typed
  # survives: `zle -I` hands the terminal over for the animation and
  # `reset-prompt` redraws the prompt (and buffer) afterwards.
  programs.zsh.initContent = ''
    matrixclear-screen() {
      zle -I
      ${lib.getExe matrixclear}
      zle reset-prompt
    }
    zle -N matrixclear-screen
    bindkey '^L' matrixclear-screen
  '';

  # Set both explicitly rather than relying on `c` expanding to the `clear` alias.
  home.shellAliases = {
    clear = "matrixclear";
    c = "matrixclear";
  };

}
