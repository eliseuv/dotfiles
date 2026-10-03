{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.apps.enable {

    home.packages = with pkgs; [

      typst

      # LSP
      tinymist

      # Formatter
      typstyle
      prettypst

      # Packager manager
      utpm

    ];

  };

}
