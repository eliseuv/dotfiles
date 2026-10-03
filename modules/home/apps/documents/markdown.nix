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
      # Render
      glow

    ];

  };

}
