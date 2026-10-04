{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.apps.enable {

    home.packages = with pkgs; [

      # LSP
      marksman
      # Linter
      markdownlint-cli2
      # Formatter (`deno fmt`): unlike prettier, it leaves typst-style
      # `$ x_1 $` display math alone instead of escaping `_`
      deno
      # Render
      glow

    ];

  };

}
