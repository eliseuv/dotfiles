{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.development.enable {

    home.packages = with pkgs; [

      python3
      python3Packages.cython
      python3Packages.pytest

      basedpyright

    ];

    programs.uv = {
      enable = true;
      settings = { };
    };

    programs.ruff = {
      enable = true;
      settings = { };
    };

    # uv installed tools path
    home.sessionPath = [ "$HOME/.local/bin" ];

  };

}
